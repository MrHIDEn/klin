import 'ast.dart';
import 'token.dart';
import 'type.dart';

final class CheckError implements Exception {
  final String message;
  final SourcePos pos;

  const CheckError(this.message, this.pos);

  @override
  String toString() => '${pos.line}:${pos.col}: $message';
}

final class _Symbol {
  final String name;
  final KlinType type;
  final bool isMut;
  final SourcePos pos;

  /// A mut method receiver becomes a pointer parameter (`T *`) in C.
  final bool isPtrReceiver;

  const _Symbol({
    required this.name,
    required this.type,
    required this.isMut,
    required this.pos,
    this.isPtrReceiver = false,
  });
}

final class _Scope {
  final _Scope? parent;
  final Map<String, _Symbol> _symbols = {};

  _Scope(this.parent);

  void define(_Symbol symbol) {
    if (_symbols.containsKey(symbol.name)) {
      throw CheckError(
        'redeclaration of `${symbol.name}` in the same scope',
        symbol.pos,
      );
    }
    _symbols[symbol.name] = symbol;
  }

  _Symbol? lookup(String name) {
    final local = _symbols[name];
    if (local != null) return local;
    return parent?.lookup(name);
  }
}

final class _FuncSignature {
  final List<KlinType> paramTypes;
  final KlinType returnType;
  final SourcePos pos;
  final bool isMutReceiver;
  final bool isPub;

  const _FuncSignature({
    required this.paramTypes,
    required this.returnType,
    required this.pos,
    this.isMutReceiver = false,
    this.isPub = false,
  });
}

final class _CheckedCall {
  final KlinType type;
  final String? cName;

  const _CheckedCall(this.type, this.cName);
}

/// Symbol table and type checker. Mutates `resolvedType` on AST nodes.
final class Checker {
  _Scope _scope = _Scope(null);
  int _loopDepth = 0;
  int _deferDepth = 0;
  final Map<String, _FuncSignature> _functions = {};
  final Map<String, StructDecl> _structs = {};
  final Map<String, _FuncSignature> _methods = {};
  final List<FuncDecl> _allFunctions = [];
  Map<String, Map<String, String>> _importAliases = {};
  KlinType _currentReturn = const VoidType();
  String _currentFunction = '';
  String _currentModule = '';

  void check(Program program) {
    _functions.clear();
    _structs.clear();
    _methods.clear();
    _allFunctions
      ..clear()
      ..addAll(program.funcs);
    _importAliases = program.importAliases;
    _checkAttrs(program);
    _registerStructs(program);
    _registerFunctions(program);
    final main = program.funcs
        .where((func) => func.receiver == null && func.name == 'main')
        .toList();
    if (main.isEmpty) {
      throw CheckError('missing required `main` function', program.pos);
    }
    if (main.length != 1) {
      throw CheckError(
          'a project can contain only one `main` function', main[1].pos);
    }
    if (main.single.params.isNotEmpty) {
      throw CheckError(
          '`main` function cannot have parameters', main.single.pos);
    }

    for (final func in program.funcs) {
      if (_hasAttr(func.attrs, 'cimport')) continue;
      _scope = _Scope(null);
      _loopDepth = 0;
      _deferDepth = 0;
      _currentFunction = func.name;
      _currentModule = func.moduleName;
      _currentReturn = func.resolvedReturnType!;
      final receiver = func.receiver;
      if (receiver != null) {
        _scope.define(
          _Symbol(
            name: receiver.name,
            type: receiver.resolvedType!,
            isMut: receiver.isMut,
            pos: receiver.pos,
            isPtrReceiver: receiver.isMut,
          ),
        );
      }
      for (final param in func.params) {
        _scope.define(
          _Symbol(
            name: param.name,
            type: param.resolvedType!,
            isMut: false,
            pos: param.pos,
          ),
        );
      }
      _checkBlock(func.body!);
      if (func.name != 'main' &&
          _currentReturn is! VoidType &&
          !_returnsOnAllPaths(func.body!)) {
        throw CheckError(
          'function `${func.name}` must return a value on all paths',
          func.pos,
        );
      }
    }
  }

  void _checkAttrs(Program program) {
    final cNames = <String>{};
    for (final decl in [...program.structs, ...program.funcs]) {
      final attrs = switch (decl) {
        StructDecl(:final attrs) => attrs,
        FuncDecl(:final attrs) => attrs,
        _ => throw StateError('unknown declaration'),
      };
      for (final attr in attrs) {
        if (!{'codename', 'cimport', 'cinclude', 'link'}.contains(attr.name)) {
          throw CheckError('unknown attribute `${attr.name}`', attr.pos);
        }
        final needsArg = attr.name == 'codename' ||
            attr.name == 'cinclude' ||
            attr.name == 'link';
        if (needsArg && attr.arg == null) {
          throw CheckError(
              'attribute `${attr.name}` requires a string', attr.pos);
        }
        if (attr.name == 'cimport' && attr.arg != null) {
          throw CheckError(
              '`cimport` attribute does not accept an argument', attr.pos);
        }
        if (attr.name == 'codename' && !cNames.add(attr.arg!)) {
          throw CheckError('duplicate codename `${attr.arg}`', attr.pos);
        }
      }
      if (decl is StructDecl && _hasAttr(attrs, 'cimport')) {
        throw CheckError('`cimport` is allowed only on functions', decl.pos);
      }
      if (decl is FuncDecl) {
        final imported = _hasAttr(attrs, 'cimport');
        if (imported && decl.body != null) {
          throw CheckError('`cimport` function cannot have a body', decl.pos);
        }
        if (!imported && decl.body == null) {
          throw CheckError(
              'function without `cimport` requires a body', decl.pos);
        }
      }
    }
  }

  bool _hasAttr(List<Attr> attrs, String name) =>
      attrs.any((attr) => attr.name == name);

  void _registerFunctions(Program program) {
    for (final func in program.funcs) {
      _currentModule = func.moduleName;
      final key = func.receiver == null
          ? _key(func.moduleName, func.name)
          : '${_resolveType(func.receiver!.typeName, func.receiver!.pos).displayName}.${func.name}';
      final collection = func.receiver == null ? _functions : _methods;
      if (collection.containsKey(key)) {
        throw CheckError('redeclaration of function `${func.name}`', func.pos);
      }
      final params = <KlinType>[];
      final paramNames = <String>{};
      for (final param in func.params) {
        if (!paramNames.add(param.name)) {
          throw CheckError(
            'redeclaration of parameter `${param.name}`',
            param.pos,
          );
        }
        final type = _resolveType(param.typeName, param.pos);
        param.resolvedType = type;
        params.add(type);
      }
      final returnType = switch (func.returnTypeName) {
        null || 'void' => const VoidType(),
        final name => _resolveType(name, func.pos),
      };
      if (returnType is ArrayType) {
        throw CheckError(
          'function cannot return an array (use slice `[]T`)',
          func.pos,
        );
      }
      func.resolvedReturnType = returnType;
      final receiver = func.receiver;
      if (receiver != null) {
        final receiverType = _resolveType(receiver.typeName, receiver.pos);
        if (receiverType is! StructType) {
          throw CheckError('method receiver must be a struct', receiver.pos);
        }
        receiver.resolvedType = receiverType;
      }
      collection[key] = _FuncSignature(
        paramTypes: params,
        returnType: returnType,
        pos: func.pos,
        isMutReceiver: receiver?.isMut ?? false,
        isPub: func.isPub,
      );
    }
  }

  void _registerStructs(Program program) {
    for (final struct in program.structs) {
      final key = _key(struct.moduleName, struct.name);
      if (_structs.containsKey(key)) {
        throw CheckError(
            'redeclaration of struct `${struct.name}`', struct.pos);
      }
      _structs[key] = struct;
    }
    for (final struct in program.structs) {
      _currentModule = struct.moduleName;
      final names = <String>{};
      for (final field in struct.fields) {
        if (!names.add(field.name)) {
          throw CheckError('duplicate field `${field.name}`', field.pos);
        }
        field.resolvedType = _resolveType(field.typeName, field.pos);
      }
    }
  }

  KlinType _resolveType(String name, SourcePos pos) {
    if (name.startsWith('!')) {
      final ok = _resolveType(name.substring(1), pos);
      if (ok is VoidType || ok is ArrayType || ok is ResultType) {
        throw CheckError('invalid result type `$name`', pos);
      }
      return ResultType(ok);
    }
    if (name.startsWith('*')) {
      var rest = name.substring(1);
      var isMut = false;
      var isVolatile = false;
      if (rest.startsWith('mut ')) {
        isMut = true;
        rest = rest.substring(4);
      }
      if (rest.startsWith('volatile ')) {
        isVolatile = true;
        rest = rest.substring(9);
      }
      if (rest.isEmpty) throw CheckError('missing pointee type', pos);
      return PtrType(
        _resolveType(rest, pos),
        isMut: isMut,
        isVolatile: isVolatile,
      );
    }
    if (name.startsWith('[]')) {
      final elem = _resolveType(name.substring(2), pos);
      if (elem is! PrimType) {
        throw CheckError('slice requires a primitive element type', pos);
      }
      return SliceType(elem);
    }
    if (name.startsWith('[')) {
      final close = name.indexOf(']');
      if (close < 2) throw CheckError('invalid array type `$name`', pos);
      final lenText = name.substring(1, close).replaceAll('_', '');
      final len = int.tryParse(
        lenText.startsWith('0x') || lenText.startsWith('0X')
            ? lenText.substring(2)
            : lenText,
        radix: lenText.startsWith('0x') || lenText.startsWith('0X') ? 16 : 10,
      );
      if (len == null || len < 0 || close == name.length - 1) {
        throw CheckError('invalid array type `$name`', pos);
      }
      return ArrayType(_resolveType(name.substring(close + 1), pos), len);
    }
    if (name == 'void') return const VoidType();
    if (name == 'str') return const StrType();
    final parts = name.split('.');
    final qualifier = parts.length == 2 ? parts.first : null;
    final typeName = parts.length == 2 ? parts.last : name;
    if (parts.length > 2) {
      throw CheckError('invalid type name `$name`', pos);
    }
    final module = qualifier == null
        ? _currentModule
        : _resolveModuleQualifier(qualifier, pos);
    final struct = _structs[_key(module, typeName)];
    if (struct != null) {
      if (module != _currentModule && !struct.isPub) {
        final shown = qualifier ?? module;
        throw CheckError('struct `$shown.$typeName` is private', pos);
      }
      return StructType(module, struct.name);
    }
    if (qualifier != null) {
      throw CheckError('unknown struct `$qualifier.$typeName`', pos);
    }
    return _resolvePrimType(name, pos);
  }

  String _key(String module, String name) => '$module.$name';

  /// Maps an `import X` alias to the file module name.
  String _resolveModuleQualifier(String qualifier, SourcePos pos) {
    if (qualifier == _currentModule) return qualifier;
    final actual = _importAliases[_currentModule]?[qualifier];
    if (actual == null) {
      throw CheckError('module `$qualifier` is not imported', pos);
    }
    return actual;
  }

  PrimType _resolvePrimType(String name, SourcePos pos) {
    final kind = PrimKind.tryParse(name);
    if (kind == null) throw CheckError('unknown type `$name`', pos);
    return PrimType(kind);
  }

  void _checkBlock(Block block) {
    _scope = _Scope(_scope);
    for (final stmt in block.stmts) {
      _checkStmt(stmt);
    }
    _scope = _scope.parent!;
  }

  void _checkStmt(Stmt stmt) {
    switch (stmt) {
      case AsmStmt():
        break;

      case LetStmt(
          :final isMut,
          :final name,
          :final typeName,
          :final init,
          :final pos
        ):
        KlinType? annotated;
        if (typeName != null) {
          annotated = _resolveType(typeName, pos);
        }

        final KlinType resolved;
        if (init != null) {
          final initType = _inferExpr(init);
          if (annotated != null) {
            _expectAssignable(annotated, initType, init.pos);
            resolved = annotated;
            _materialize(init, resolved);
          } else {
            resolved = _defaultConcrete(initType, init.pos);
            _materialize(init, resolved);
          }
          if (resolved is ArrayType && init is! ArrayLitExpr) {
            throw CheckError(
              'array initialization requires a `[...]` literal',
              init.pos,
            );
          }
        } else if (annotated != null) {
          // No initializer: use the annotated type.
          resolved = annotated;
        } else {
          throw CheckError(
            'zmienna `$name` wymaga typu lub inicjalizatora',
            pos,
          );
        }

        stmt.resolvedType = resolved;
        _scope.define(
          _Symbol(name: name, type: resolved, isMut: isMut, pos: pos),
        );

      case AssignStmt(:final target, :final value, :final pos):
        final targetType = _checkAssignableTarget(target, pos);
        if (targetType is ArrayType) {
          throw CheckError(
            'cannot assign an entire array (assign elements or use a slice)',
            pos,
          );
        }
        final valueType = _inferExpr(value);
        _expectAssignable(targetType, valueType, value.pos);
        _materialize(value, targetType);

      case CallStmt(:final moduleName, :final callee, :final args, :final pos):
        final call = _checkCall(callee, args, pos, moduleName: moduleName);
        if (call.type is ResultType) {
          throw CheckError(
            'result `${call.type.displayName}` from function `$callee` must be handled with `!` or `or`',
            pos,
          );
        }
        stmt.resolvedCallee = call.cName;

      case MethodCallStmt(:final call):
        final type = _checkMethodCall(call);
        if (type is ResultType) {
          throw CheckError(
            'result `${type.displayName}` from method `${call.name}` must be handled with `!` or `or`',
            call.pos,
          );
        }

      case IfStmt(:final cond, :final thenBlock, :final elseBranch):
        _expectBoolCond(cond);
        _checkBlock(thenBlock);
        if (elseBranch != null) _checkStmt(elseBranch);

      case WhileStmt(:final cond, :final body):
        _expectBoolCond(cond);
        _loopDepth++;
        _checkBlock(body);
        _loopDepth--;

      case ForRangeStmt(
          :final name,
          :final start,
          :final endExclusive,
          :final body,
          :final pos
        ):
        final startTy = _inferExpr(start);
        final endTy = _inferExpr(endExclusive);
        final unified = _unifyNumeric(startTy, endTy, pos);
        final concrete = _defaultConcrete(unified, pos);
        if (concrete is! PrimType || !concrete.kind.isInteger) {
          throw CheckError(
            '`for` range requires integer types, got `${concrete.displayName}`',
            pos,
          );
        }
        _materialize(start, concrete);
        _materialize(endExclusive, concrete);
        stmt.resolvedType = concrete;

        _scope = _Scope(_scope);
        _scope.define(
          _Symbol(name: name, type: concrete, isMut: true, pos: pos),
        );
        _loopDepth++;
        _checkBlock(body);
        _loopDepth--;
        _scope = _scope.parent!;

      case ForCStmt(
          :final initName,
          :final initExpr,
          :final cond,
          :final postName,
          :final postExpr,
          :final body,
          :final pos
        ):
        _scope = _Scope(_scope);
        if (initName != null && initExpr != null) {
          final initTy = _inferExpr(initExpr);
          final concrete = _defaultConcrete(initTy, initExpr.pos);
          _materialize(initExpr, concrete);
          stmt.resolvedInitType = concrete;
          _scope.define(
            _Symbol(name: initName, type: concrete, isMut: true, pos: pos),
          );
        }
        if (cond != null) _expectBoolCond(cond);
        if (postName != null && postExpr != null) {
          final sym = _scope.lookup(postName);
          if (sym == null) {
            throw CheckError('unknown variable `$postName`', postExpr.pos);
          }
          if (!sym.isMut) {
            throw CheckError(
              'cannot assign to immutable variable `$postName`',
              postExpr.pos,
            );
          }
          final postTy = _inferExpr(postExpr);
          _expectAssignable(sym.type, postTy, postExpr.pos);
          _materialize(postExpr, sym.type);
        }
        _loopDepth++;
        _checkBlock(body);
        _loopDepth--;
        _scope = _scope.parent!;

      case ReturnStmt(:final value, :final pos):
        _checkReturn(value, pos);

      case BreakStmt(:final pos):
        if (_loopDepth == 0) {
          throw CheckError('`break` outside a loop', pos);
        }

      case ContinueStmt(:final pos):
        if (_loopDepth == 0) {
          throw CheckError('`continue` outside a loop', pos);
        }

      case DeferStmt(:final body, :final pos):
        if (_deferDepth > 0) {
          throw CheckError('`defer` inside `defer`', pos);
        }
        _deferDepth++;
        try {
          _checkStmt(body);
        } finally {
          _deferDepth--;
        }

      case BlockStmt(:final block):
        _checkBlock(block);
    }
  }

  void _expectBoolCond(Expr cond) {
    final t = _inferExpr(cond);
    // Comparisons already yield bool. A bool literal is valid; untyped values and numbers are not.
    if (t is PrimType && t.kind == PrimKind.bool_) {
      return;
    }
    throw CheckError(
      'condition requires type `bool`, got `${t.displayName}`',
      cond.pos,
    );
  }

  void _checkReturn(Expr? value, SourcePos pos) {
    if (_currentFunction == 'main') {
      if (value == null) return;
      final type = _defaultConcrete(_inferExpr(value), value.pos);
      if (type is! PrimType || !type.kind.isInteger) {
        throw CheckError(
          '`return` in main requires an integer type, got `${type.displayName}`',
          value.pos,
        );
      }
      _materialize(value, type);
      return;
    }
    if (_currentReturn is VoidType) {
      if (value != null) {
        throw CheckError('void function cannot return a value', value.pos);
      }
      return;
    }
    if (value == null) {
      throw CheckError(
        'function `${_currentFunction}` must return `${_currentReturn.displayName}`',
        pos,
      );
    }
    final valueType = _inferExpr(value);
    if (_currentReturn case ResultType(:final ok)) {
      if (valueType == _currentReturn) {
        _materialize(value, _currentReturn);
      } else {
        _expectAssignable(ok, valueType, value.pos);
        _materialize(value, ok);
      }
      return;
    }
    _expectAssignable(_currentReturn, valueType, value.pos);
    _materialize(value, _currentReturn);
  }

  _CheckedCall _checkCall(
    String callee,
    List<Expr> args,
    SourcePos pos, {
    String? moduleName,
  }) {
    final local = _scope.lookup(callee);
    if (local != null && moduleName == null) {
      throw CheckError(
        '`$callee` is not a function (it is a `${local.type.displayName}` variable)',
        pos,
      );
    }
    final String module;
    if (moduleName != null) {
      module = _resolveModuleQualifier(moduleName, pos);
    } else {
      module = _currentModule;
    }
    final signature = _functions[_key(module, callee)];
    if (signature == null) {
      if (moduleName != null) {
        throw CheckError('nieznana funkcja `$moduleName.$callee`', pos);
      }
      final elsewhere = _allFunctions
          .where((func) => func.receiver == null && func.name == callee)
          .toList();
      if (elsewhere.isNotEmpty) {
        final mod = elsewhere.first.moduleName;
        throw CheckError(
          'function `$callee` is in module `$mod` — use `$mod.$callee`',
          pos,
        );
      }
      // C FFI (for example puts/printf): its signature is unknown.
      for (final arg in args) {
        _inferExpr(arg);
      }
      return const _CheckedCall(PrimType(PrimKind.i32), null);
    }
    final decl = _functionDecl(module, callee);
    if (module != _currentModule && !decl.isPub) {
      final shown = moduleName ?? module;
      throw CheckError('function `$shown.$callee` is private', pos);
    }
    if (args.length != signature.paramTypes.length) {
      throw CheckError(
        'function `$callee` expects ${signature.paramTypes.length} arguments, '
        'got ${args.length}',
        pos,
      );
    }
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      final expected = signature.paramTypes[i];
      final actual = _inferExpr(arg);
      _expectAssignable(expected, actual, arg.pos);
      _materialize(arg, expected);
    }
    return _CheckedCall(signature.returnType, _cNameForFunction(decl));
  }

  FuncDecl _functionDecl(String module, String name) =>
      _allFunctions.firstWhere((func) =>
          func.receiver == null &&
          func.moduleName == module &&
          func.name == name);

  String _mangledFreeName(String module, String name) =>
      module.isEmpty ? name : '${module}_$name';

  String _cNameForFunction(FuncDecl func) {
    for (final attr in func.attrs) {
      if (attr.name == 'codename') return attr.arg!;
    }
    return _mangledFreeName(func.moduleName, func.name);
  }

  KlinType _checkMethodCall(MethodCallExpr call) {
    final receiverType = _inferExpr(call.receiver);
    if (receiverType is! StructType) {
      throw CheckError(
          'method requires a struct, got `${receiverType.displayName}`',
          call.pos);
    }
    final signature = _methods['${receiverType.displayName}.${call.name}'];
    if (signature == null) {
      throw CheckError(
          'struct `${receiverType.name}` has no method `${call.name}`',
          call.pos);
    }
    if (receiverType.moduleName != _currentModule && !signature.isPub) {
      throw CheckError(
        'method `${receiverType.moduleName}.${receiverType.name}.${call.name}` is private',
        call.pos,
      );
    }
    if (signature.isMutReceiver) {
      if (call.receiver is! NameExpr) {
        throw CheckError(
            'mutating method requires a mutable variable', call.receiver.pos);
      }
      final receiver = call.receiver as NameExpr;
      final symbol = _scope.lookup(receiver.name);
      if (symbol == null || !symbol.isMut) {
        throw CheckError(
            'cannot call a mutating method on an immutable variable',
            call.receiver.pos);
      }
    }
    if (call.args.length != signature.paramTypes.length) {
      throw CheckError(
        'method `${call.name}` expects ${signature.paramTypes.length} arguments, got ${call.args.length}',
        call.pos,
      );
    }
    for (var i = 0; i < call.args.length; i++) {
      final arg = call.args[i];
      final expected = signature.paramTypes[i];
      _expectAssignable(expected, _inferExpr(arg), arg.pos);
      _materialize(arg, expected);
    }
    call.mangledName =
        '${receiverType.moduleName}_${receiverType.name}_${call.name}';
    call.receiverByRef = signature.isMutReceiver;
    return signature.returnType;
  }

  KlinType _checkAssignableTarget(Expr target, SourcePos pos) {
    final place = _unwrapGroups(target);
    if (place is NameExpr) {
      final symbol = _scope.lookup(place.name);
      if (symbol == null)
        throw CheckError('unknown variable `${place.name}`', pos);
      if (!symbol.isMut) {
        throw CheckError(
            'cannot assign to immutable variable `${place.name}`', pos);
      }
      place.isPtrReceiver = symbol.isPtrReceiver;
      return symbol.type;
    }
    if (place is FieldExpr) {
      final objectType = _inferExpr(place.object);
      if (objectType is ArrayType || objectType is SliceType) {
        throw CheckError('`len` is read-only', pos);
      }
      _requireMutableStructPlace(place.object, pos);
      return _inferExpr(place);
    }
    if (place is UnaryExpr && place.op == '*') {
      final pointer = _inferExpr(place.operand);
      if (pointer is! PtrType) {
        throw CheckError('dereference requires a pointer', pos);
      }
      if (!pointer.isMut) {
        throw CheckError('cannot write through an immutable pointer', pos);
      }
      return pointer.pointee;
    }
    if (place is IndexExpr) {
      final type = _inferExpr(place);
      _requireMutableArrayPlace(place.object, pos);
      return type;
    }
    throw CheckError('invalid assignment target', pos);
  }

  void _requireMutableStructPlace(Expr object, SourcePos pos) {
    final base = _unwrapGroups(object);
    if (base is NameExpr) {
      final symbol = _scope.lookup(base.name);
      if (symbol == null) {
        throw CheckError('nieznana zmienna `${base.name}`', pos);
      }
      if (!symbol.isMut) {
        throw CheckError(
            'cannot assign to a field of an immutable variable', pos);
      }
      base.isPtrReceiver = symbol.isPtrReceiver;
      return;
    }
    throw CheckError(
        'cannot assign to a field of an immutable expression', pos);
  }

  void _requireMutableArrayPlace(Expr object, SourcePos pos) {
    final base = _unwrapGroups(object);
    if (base is NameExpr) {
      final symbol = _scope.lookup(base.name);
      if (symbol == null)
        throw CheckError('nieznana zmienna `${base.name}`', pos);
      if (!symbol.isMut) {
        throw CheckError('cannot assign to an immutable array', pos);
      }
      return;
    }
    throw CheckError('cannot assign through an immutable expression', pos);
  }

  Expr _unwrapGroups(Expr expr) {
    var current = expr;
    while (current is GroupExpr) {
      current = current.inner;
    }
    return current;
  }

  bool _returnsOnAllPaths(Block block) {
    for (final stmt in block.stmts) {
      if (_stmtReturns(stmt)) return true;
    }
    return false;
  }

  bool _stmtReturns(Stmt stmt) => switch (stmt) {
        ReturnStmt() => true,
        BlockStmt(:final block) => _returnsOnAllPaths(block),
        IfStmt(:final thenBlock, :final elseBranch) => elseBranch != null &&
            _returnsOnAllPaths(thenBlock) &&
            _stmtReturns(elseBranch),
        _ => false,
      };

  /// Infers without context; may return an untyped type.
  KlinType _inferExpr(Expr expr) {
    final type = switch (expr) {
      IntLit() => const UntypedInt(),
      FloatLit() => const UntypedFloat(),
      BoolLit() => const PrimType(PrimKind.bool_),
      StringLit() => const StrType(),
      NameExpr nameExpr => () {
          final sym = _scope.lookup(nameExpr.name);
          if (sym == null) {
            throw CheckError(
                'nieznana zmienna `${nameExpr.name}`', nameExpr.pos);
          }
          nameExpr.isPtrReceiver = sym.isPtrReceiver;
          return sym.type;
        }(),
      FieldExpr(:final object, :final name, :final pos) => () {
          final objectType = _inferExpr(object);
          if (name == 'len' && objectType is ArrayType) {
            return const PrimType(PrimKind.i32);
          }
          if (name == 'len' && objectType is SliceType) {
            return const PrimType(PrimKind.i32);
          }
          if (objectType is! StructType) {
            throw CheckError(
                'field access requires a struct, got `${objectType.displayName}`',
                pos);
          }
          FieldDecl? field;
          for (final candidate
              in _structs[_key(objectType.moduleName, objectType.name)]!
                  .fields) {
            if (candidate.name == name) {
              field = candidate;
              break;
            }
          }
          if (field == null) {
            throw CheckError(
                'struct `${objectType.name}` has no field `$name`', pos);
          }
          return field.resolvedType!;
        }(),
      IndexExpr(:final object, :final index, :final pos) => () {
          final objectType = _inferExpr(object);
          final indexType = _defaultConcrete(_inferExpr(index), index.pos);
          if (indexType is! PrimType || !indexType.kind.isInteger) {
            throw CheckError('index requires an integer type', index.pos);
          }
          _materialize(index, indexType);
          return switch (objectType) {
            ArrayType(:final elem) => elem,
            SliceType(:final elem) => elem,
            _ => throw CheckError(
                'indexing requires an array or slice, got `${objectType.displayName}`',
                pos,
              ),
          };
        }(),
      SliceFromExpr(:final array, :final pos) => () {
          if (!_isAddressablePlace(array)) {
            throw CheckError(
              '`[:]` requires an array l-value, not a literal or temporary expression',
              pos,
            );
          }
          final arrayType = _inferExpr(array);
          if (arrayType is! ArrayType || arrayType.elem is! PrimType) {
            throw CheckError(
                '`[:]` requires an array with a primitive element type', pos);
          }
          return SliceType(arrayType.elem as PrimType);
        }(),
      ArrayLitExpr(:final elements, :final pos) => () {
          if (elements.isEmpty) {
            throw CheckError('cannot infer the type of an empty array', pos);
          }
          var elemType = _inferExpr(elements.first);
          for (final element in elements.skip(1)) {
            final nextType = _inferExpr(element);
            elemType = (elemType is PrimType ||
                        elemType is UntypedInt ||
                        elemType is UntypedFloat) &&
                    (nextType is PrimType ||
                        nextType is UntypedInt ||
                        nextType is UntypedFloat)
                ? _unifyNumeric(elemType, nextType, element.pos)
                : (elemType == nextType
                    ? elemType
                    : throw CheckError(
                        'array element type mismatch: `${elemType.displayName}` and `${nextType.displayName}`',
                        element.pos,
                      ));
          }
          elemType = _defaultConcrete(elemType, pos);
          for (final element in elements) {
            _expectAssignable(elemType, _inferExpr(element), element.pos);
            _materialize(element, elemType);
          }
          return ArrayType(elemType, elements.length);
        }(),
      CastExpr(:final typeName, :final expr, :final pos) => () {
          final target = _resolveType(typeName, pos);
          if (target is! PtrType) {
            throw CheckError('MVP cast supports only pointer types', pos);
          }
          final source = _inferExpr(expr);
          if (source is! UntypedInt &&
              source is! PrimType &&
              source is! PtrType) {
            throw CheckError(
                'pointer cast requires an integer or pointer', pos);
          }
          return target;
        }(),
      MethodCallExpr() => _checkMethodCall(expr),
      StructLitExpr(
        :final moduleName,
        :final typeName,
        :final namedFields,
        :final positionalFields,
        :final pos
      ) =>
        () {
          final module = moduleName == null
              ? _currentModule
              : _resolveModuleQualifier(moduleName, pos);
          final struct = _structs[_key(module, typeName)];
          if (struct == null) {
            final shown =
                moduleName == null ? typeName : '$moduleName.$typeName';
            throw CheckError('unknown struct `$shown`', pos);
          }
          if (module != _currentModule && !struct.isPub) {
            final shown = moduleName ?? module;
            throw CheckError('struct `$shown.$typeName` is private', pos);
          }
          if (namedFields != null) {
            if (namedFields.length != struct.fields.length) {
              throw CheckError('literal `$typeName` requires all fields', pos);
            }
            for (final field in struct.fields) {
              final value = namedFields[field.name];
              if (value == null)
                throw CheckError(
                    'missing field `${field.name}` in literal', pos);
              _expectAssignable(
                  field.resolvedType!, _inferExpr(value), value.pos);
              _materialize(value, field.resolvedType!);
            }
          } else {
            final values = positionalFields!;
            if (values.length != struct.fields.length) {
              throw CheckError(
                  'literal `$typeName` expects ${struct.fields.length} fields',
                  pos);
            }
            for (var i = 0; i < values.length; i++) {
              _expectAssignable(struct.fields[i].resolvedType!,
                  _inferExpr(values[i]), values[i].pos);
              _materialize(values[i], struct.fields[i].resolvedType!);
            }
          }
          return StructType(module, typeName);
        }(),
      CallExpr(:final moduleName, :final callee, :final args, :final pos) =>
        () {
          final call = _checkCall(callee, args, pos, moduleName: moduleName);
          expr.resolvedCallee = call.cName;
          if (call.type is VoidType) {
            throw CheckError(
              'result of void function `$callee` cannot be used as a value',
              pos,
            );
          }
          return call.type;
        }(),
      ErrorExpr(:final code, :final pos) => () {
          final current = _currentReturn;
          if (current is! ResultType) {
            throw CheckError(
                '`error(...)` requires a function returning `!T`', pos);
          }
          final codeType = _inferExpr(code);
          _expectAssignable(const PrimType(PrimKind.i32), codeType, code.pos);
          _materialize(code, const PrimType(PrimKind.i32));
          return current;
        }(),
      PropagateExpr(:final result, :final pos) => () {
          final resultType = _inferExpr(result);
          if (resultType is! ResultType) {
            throw CheckError('postfix operator `!` requires a `!T` value', pos);
          }
          if (_currentReturn is! ResultType) {
            throw CheckError(
              'postfix operator `!` requires a function returning `!T`',
              pos,
            );
          }
          return resultType.ok;
        }(),
      OrExpr(:final result, :final fallback, :final pos) => () {
          final resultType = _inferExpr(result);
          if (resultType is! ResultType) {
            throw CheckError('left side of `or` must have type `!T`', pos);
          }
          _scope = _Scope(_scope);
          try {
            _scope.define(
              _Symbol(
                name: 'err',
                type: const PrimType(PrimKind.i32),
                isMut: false,
                pos: fallback.pos,
              ),
            );
            for (final stmt in fallback.stmts) {
              _checkStmt(stmt);
            }
            final fallbackType = _inferExpr(fallback.value);
            _expectAssignable(resultType.ok, fallbackType, fallback.value.pos);
            _materialize(fallback.value, resultType.ok);
          } finally {
            _scope = _scope.parent!;
          }
          return resultType.ok;
        }(),
      UnaryExpr(:final op, :final operand, :final pos) => () {
          if (op == '&') {
            if (!_isAddressablePlace(operand)) {
              throw CheckError(
                  'operator `&` requires an addressable location', pos);
            }
            final pointee = _inferExpr(operand);
            return PtrType(
              pointee,
              isMut: _isMutablePlace(operand),
            );
          }
          if (op == '*') {
            final pointer = _inferExpr(operand);
            if (pointer is! PtrType) {
              throw CheckError('dereference requires a pointer', pos);
            }
            return pointer.pointee;
          }
          if (op == '!') {
            final t = _inferExpr(operand);
            if (t is! PrimType || t.kind != PrimKind.bool_) {
              throw CheckError(
                'operator `!` requires type `bool`, got `${t.displayName}`',
                pos,
              );
            }
            return const PrimType(PrimKind.bool_);
          }
          if (op != '-') {
            throw CheckError('unknown unary operator `$op`', pos);
          }
          final t = _inferExpr(operand);
          final concrete = _defaultConcrete(t, operand.pos);
          if (concrete is! PrimType ||
              !(concrete.kind.isInteger || concrete.kind.isFloat)) {
            throw CheckError(
              'operator `-` requires a numeric type, got `${concrete.displayName}`',
              pos,
            );
          }
          if (_isUnsigned(concrete.kind)) {
            throw CheckError(
              'operator `-` is not allowed for unsigned type `${concrete.displayName}`',
              pos,
            );
          }
          _materialize(operand, concrete);
          return concrete;
        }(),
      BinaryExpr(:final left, :final op, :final right, :final pos) =>
        _inferBinary(left, op, right, pos),
      GroupExpr(:final inner) => _inferExpr(inner),
    };
    if (type is PrimType ||
        type is StrType ||
        type is StructType ||
        type is PtrType ||
        type is ArrayType ||
        type is SliceType ||
        type is ResultType) expr.resolvedType = type;
    return type;
  }

  bool _isMutablePlace(Expr expr) {
    final place = _unwrapGroups(expr);
    if (place is NameExpr) return _scope.lookup(place.name)?.isMut ?? false;
    if (place is FieldExpr) return _isMutablePlace(place.object);
    if (place is IndexExpr) return _isMutablePlace(place.object);
    return false;
  }

  bool _isAddressablePlace(Expr expr) {
    final place = _unwrapGroups(expr);
    return place is NameExpr || place is FieldExpr || place is IndexExpr;
  }

  static const _cmpOps = {'==', '!=', '<', '<=', '>', '>='};
  static const _arithOps = {'+', '-', '*', '/', '%'};

  KlinType _inferBinary(Expr left, String op, Expr right, SourcePos pos) {
    if (_cmpOps.contains(op)) {
      return _inferComparison(left, op, right, pos);
    }
    if (!_arithOps.contains(op)) {
      throw CheckError('unknown operator `$op`', pos);
    }

    final lt = _inferExpr(left);
    final rt = _inferExpr(right);
    final unified = _unifyNumeric(lt, rt, pos);
    final concrete = unified is UntypedInt || unified is UntypedFloat
        ? _defaultConcrete(unified, pos)
        : unified;

    if (concrete is! PrimType ||
        !(concrete.kind.isInteger || concrete.kind.isFloat)) {
      throw CheckError(
        'operator `$op` requires numeric types, got `${concrete.displayName}`',
        pos,
      );
    }

    if (op == '%' && !concrete.kind.isInteger) {
      throw CheckError(
        'operator `%` requires integer types, got `${concrete.displayName}`',
        pos,
      );
    }

    _materialize(left, concrete);
    _materialize(right, concrete);
    return concrete;
  }

  KlinType _inferComparison(Expr left, String op, Expr right, SourcePos pos) {
    final lt = _inferExpr(left);
    final rt = _inferExpr(right);

    // bool == bool / !=
    if (lt is PrimType &&
        lt.kind == PrimKind.bool_ &&
        rt is PrimType &&
        rt.kind == PrimKind.bool_) {
      if (op != '==' && op != '!=') {
        throw CheckError(
          'operator `$op` is not allowed for type `bool`',
          pos,
        );
      }
      return const PrimType(PrimKind.bool_);
    }

    final unified = _unifyNumeric(lt, rt, pos);
    final concrete = unified is UntypedInt || unified is UntypedFloat
        ? _defaultConcrete(unified, pos)
        : unified;

    if (concrete is! PrimType ||
        !(concrete.kind.isInteger || concrete.kind.isFloat)) {
      throw CheckError(
        'operator `$op` requires numeric types, got `${concrete.displayName}`',
        pos,
      );
    }

    _materialize(left, concrete);
    _materialize(right, concrete);
    return const PrimType(PrimKind.bool_);
  }

  KlinType _unifyNumeric(KlinType lt, KlinType rt, SourcePos pos) {
    if (lt is UntypedInt && rt is UntypedInt) {
      return const UntypedInt();
    } else if (lt is UntypedFloat && rt is UntypedFloat) {
      return const UntypedFloat();
    } else if (lt is UntypedInt && rt is UntypedFloat) {
      return const UntypedFloat();
    } else if (lt is UntypedFloat && rt is UntypedInt) {
      return const UntypedFloat();
    } else if (lt is UntypedInt && rt is PrimType && rt.kind.isInteger) {
      return rt;
    } else if (rt is UntypedInt && lt is PrimType && lt.kind.isInteger) {
      return lt;
    } else if (lt is UntypedFloat && rt is PrimType && rt.kind.isFloat) {
      return rt;
    } else if (rt is UntypedFloat && lt is PrimType && lt.kind.isFloat) {
      return lt;
    } else if (lt is UntypedInt && rt is PrimType && rt.kind.isFloat) {
      return rt;
    } else if (rt is UntypedInt && lt is PrimType && lt.kind.isFloat) {
      return lt;
    } else if (lt == rt) {
      return lt;
    } else {
      throw CheckError(
        'type mismatch: `${lt.displayName}` and `${rt.displayName}`',
        pos,
      );
    }
  }

  /// Assigns a concrete type to an expression and recursively to subtrees
  /// containing untyped literals.
  void _materialize(Expr expr, KlinType type) {
    // `cast(T, x)` preserves its explicit type T; do not overwrite it from an outer context.
    if (expr is CastExpr) return;
    if (type is SliceType && expr.resolvedType is ArrayType) {
      expr.arrayToSliceFrom = expr.resolvedType as ArrayType;
    }
    expr.resolvedType = type;
    switch (expr) {
      case UnaryExpr(:final operand, :final op):
        if (op != '&' && op != '*') _materialize(operand, type);
      case BinaryExpr(:final left, :final right, :final op):
        if (_cmpOps.contains(op)) {
          // Comparison operands have a numeric type; the node itself has bool.
          // When materializing bool from above, do not descend: _inferComparison
          // already assigned operand types.
          break;
        }
        _materialize(left, type);
        _materialize(right, type);
      case GroupExpr(:final inner):
        _materialize(inner, type);
      case PropagateExpr() || OrExpr() || ErrorExpr():
        break;
      case IntLit() ||
            FloatLit() ||
            BoolLit() ||
            StringLit() ||
            NameExpr() ||
            CallExpr() ||
            FieldExpr() ||
            MethodCallExpr() ||
            StructLitExpr() ||
            IndexExpr() ||
            SliceFromExpr() ||
            CastExpr():
        break;
      case ArrayLitExpr(:final elements):
        if (type is! ArrayType) break;
        for (final element in elements) {
          _expectAssignable(type.elem, _inferExpr(element), element.pos);
          _materialize(element, type.elem);
        }
    }
  }

  void _expectAssignable(KlinType target, KlinType source, SourcePos pos) {
    if (!_isAssignable(target, source)) {
      throw CheckError(
        'type mismatch: expected `${target.displayName}`, '
        'got `${source.displayName}`',
        pos,
      );
    }
  }

  bool _isAssignable(KlinType target, KlinType source) {
    if (target == source) return true;
    if (source is UntypedInt && target is PrimType && target.kind.isInteger) {
      return true;
    }
    if (source is UntypedFloat && target is PrimType && target.kind.isFloat) {
      return true;
    }
    if (source is UntypedInt && target is PrimType && target.kind.isFloat) {
      return true;
    }
    if (target is SliceType &&
        source is ArrayType &&
        source.elem == target.elem) {
      return true;
    }
    if (target is PtrType &&
        source is PtrType &&
        target.pointee == source.pointee &&
        target.isVolatile == source.isVolatile &&
        (!target.isMut || source.isMut)) {
      return true;
    }
    return false;
  }

  KlinType _defaultConcrete(KlinType type, SourcePos pos) {
    return switch (type) {
      UntypedInt() => const PrimType(PrimKind.i32),
      UntypedFloat() => const PrimType(PrimKind.f64),
      PrimType() => type,
      StructType() => type,
      PtrType() => type,
      ArrayType() => type,
      SliceType() => type,
      ResultType() => type,
      VoidType() => throw CheckError(
          'cannot use a void value in this context',
          pos,
        ),
      StrType() => throw CheckError(
          'cannot use a string in this context',
          pos,
        ),
    };
  }

  static bool _isUnsigned(PrimKind kind) => switch (kind) {
        PrimKind.u8 ||
        PrimKind.u16 ||
        PrimKind.u32 ||
        PrimKind.u64 ||
        PrimKind.usize =>
          true,
        _ => false,
      };
}
