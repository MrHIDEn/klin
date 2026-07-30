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

  /// Mut receiver metody — w C parametr wskaźnikowy (`T *`).
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
        'ponowna deklaracja `${symbol.name}` w tym samym zakresie',
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

/// Tablica symboli + sprawdzanie typów. Mutuje `resolvedType` na węzłach AST.
final class Checker {
  _Scope _scope = _Scope(null);
  int _loopDepth = 0;
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
    _registerStructs(program);
    _registerFunctions(program);
    final main = program.funcs
        .where((func) => func.receiver == null && func.name == 'main')
        .toList();
    if (main.isEmpty) {
      throw CheckError('brak wymaganej funkcji `main`', program.pos);
    }
    if (main.length != 1) {
      throw CheckError(
          'w projekcie może być tylko jedna funkcja `main`', main[1].pos);
    }
    if (main.single.params.isNotEmpty) {
      throw CheckError(
          'funkcja `main` nie może mieć parametrów', main.single.pos);
    }

    for (final func in program.funcs) {
      _scope = _Scope(null);
      _loopDepth = 0;
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
      _checkBlock(func.body);
      if (func.name != 'main' &&
          _currentReturn is! VoidType &&
          !_returnsOnAllPaths(func.body)) {
        throw CheckError(
          'funkcja `${func.name}` musi zwrócić wartość na wszystkich ścieżkach',
          func.pos,
        );
      }
    }
  }

  void _registerFunctions(Program program) {
    for (final func in program.funcs) {
      _currentModule = func.moduleName;
      final key = func.receiver == null
          ? _key(func.moduleName, func.name)
          : '${_resolveType(func.receiver!.typeName, func.receiver!.pos).displayName}.${func.name}';
      final collection = func.receiver == null ? _functions : _methods;
      if (collection.containsKey(key)) {
        throw CheckError('ponowna deklaracja funkcji `${func.name}`', func.pos);
      }
      final params = <KlinType>[];
      final paramNames = <String>{};
      for (final param in func.params) {
        if (!paramNames.add(param.name)) {
          throw CheckError(
            'ponowna deklaracja parametru `${param.name}`',
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
      func.resolvedReturnType = returnType;
      final receiver = func.receiver;
      if (receiver != null) {
        final receiverType = _resolveType(receiver.typeName, receiver.pos);
        if (receiverType is! StructType) {
          throw CheckError('receiver metody musi być strukturą', receiver.pos);
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
            'ponowna deklaracja struktury `${struct.name}`', struct.pos);
      }
      _structs[key] = struct;
    }
    for (final struct in program.structs) {
      _currentModule = struct.moduleName;
      final names = <String>{};
      for (final field in struct.fields) {
        if (!names.add(field.name)) {
          throw CheckError('powtórzone pole `${field.name}`', field.pos);
        }
        field.resolvedType = _resolveType(field.typeName, field.pos);
      }
    }
  }

  KlinType _resolveType(String name, SourcePos pos) {
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
      if (rest.isEmpty) throw CheckError('brak typu wskazywanego', pos);
      return PtrType(
        _resolveType(rest, pos),
        isMut: isMut,
        isVolatile: isVolatile,
      );
    }
    if (name.startsWith('[]')) {
      final elem = _resolveType(name.substring(2), pos);
      if (elem is! PrimType) {
        throw CheckError('slice wymaga typu prymitywnego elementu', pos);
      }
      return SliceType(elem);
    }
    if (name.startsWith('[')) {
      final close = name.indexOf(']');
      if (close < 2) throw CheckError('niepoprawny typ tablicy `$name`', pos);
      final lenText = name.substring(1, close).replaceAll('_', '');
      final len = int.tryParse(
        lenText.startsWith('0x') || lenText.startsWith('0X')
            ? lenText.substring(2)
            : lenText,
        radix: lenText.startsWith('0x') || lenText.startsWith('0X') ? 16 : 10,
      );
      if (len == null || len < 0 || close == name.length - 1) {
        throw CheckError('niepoprawny typ tablicy `$name`', pos);
      }
      return ArrayType(_resolveType(name.substring(close + 1), pos), len);
    }
    if (name == 'void') return const VoidType();
    final parts = name.split('.');
    final qualifier = parts.length == 2 ? parts.first : null;
    final typeName = parts.length == 2 ? parts.last : name;
    if (parts.length > 2) {
      throw CheckError('niepoprawna nazwa typu `$name`', pos);
    }
    final module = qualifier == null
        ? _currentModule
        : _resolveModuleQualifier(qualifier, pos);
    final struct = _structs[_key(module, typeName)];
    if (struct != null) {
      if (module != _currentModule && !struct.isPub) {
        final shown = qualifier ?? module;
        throw CheckError('struktura `$shown.$typeName` jest prywatna', pos);
      }
      return StructType(module, struct.name);
    }
    if (qualifier != null) {
      throw CheckError('nieznana struktura `$qualifier.$typeName`', pos);
    }
    return _resolvePrimType(name, pos);
  }

  String _key(String module, String name) => '$module.$name';

  /// Alias z `import X` → faktyczna nazwa modułu pliku.
  String _resolveModuleQualifier(String qualifier, SourcePos pos) {
    if (qualifier == _currentModule) return qualifier;
    final actual = _importAliases[_currentModule]?[qualifier];
    if (actual == null) {
      throw CheckError('moduł `$qualifier` nie jest zaimportowany', pos);
    }
    return actual;
  }

  PrimType _resolvePrimType(String name, SourcePos pos) {
    final kind = PrimKind.tryParse(name);
    if (kind == null) throw CheckError('nieznany typ `$name`', pos);
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
        } else if (annotated != null) {
          // ZII — brak inicjalizatora, typ z adnotacji.
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
        final valueType = _inferExpr(value);
        _expectAssignable(targetType, valueType, value.pos);
        _materialize(value, targetType);

      case CallStmt(:final moduleName, :final callee, :final args, :final pos):
        stmt.resolvedCallee =
            _checkCall(callee, args, pos, moduleName: moduleName).cName;

      case MethodCallStmt(:final call):
        _checkMethodCall(call);

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
            'zakres `for` wymaga typów całkowitych, dostano `${concrete.displayName}`',
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
            throw CheckError('nieznana zmienna `$postName`', postExpr.pos);
          }
          if (!sym.isMut) {
            throw CheckError(
              'nie można przypisać do niemutowalnej zmiennej `$postName`',
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
          throw CheckError('`break` poza pętlą', pos);
        }

      case ContinueStmt(:final pos):
        if (_loopDepth == 0) {
          throw CheckError('`continue` poza pętlą', pos);
        }

      case BlockStmt(:final block):
        _checkBlock(block);
    }
  }

  void _expectBoolCond(Expr cond) {
    final t = _inferExpr(cond);
    // Porównania już dają bool. Literał bool OK. Untyped/liczby — nie.
    if (t is PrimType && t.kind == PrimKind.bool_) {
      return;
    }
    throw CheckError(
      'warunek wymaga typu `bool`, dostano `${t.displayName}`',
      cond.pos,
    );
  }

  void _checkReturn(Expr? value, SourcePos pos) {
    if (_currentFunction == 'main') {
      if (value == null) return;
      final type = _defaultConcrete(_inferExpr(value), value.pos);
      if (type is! PrimType || !type.kind.isInteger) {
        throw CheckError(
          '`return` w main wymaga typu całkowitego, dostano `${type.displayName}`',
          value.pos,
        );
      }
      _materialize(value, type);
      return;
    }
    if (_currentReturn is VoidType) {
      if (value != null) {
        throw CheckError('funkcja void nie może zwracać wartości', value.pos);
      }
      return;
    }
    if (value == null) {
      throw CheckError(
        'funkcja `${_currentFunction}` musi zwrócić `${_currentReturn.displayName}`',
        pos,
      );
    }
    final valueType = _inferExpr(value);
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
        '`$callee` nie jest funkcją (to zmienna `${local.type.displayName}`)',
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
          'funkcja `$callee` jest w module `$mod` — użyj `$mod.$callee`',
          pos,
        );
      }
      // FFI do C (np. puts/printf) — nie znamy sygnatury.
      for (final arg in args) {
        _inferExpr(arg);
      }
      return const _CheckedCall(PrimType(PrimKind.i32), null);
    }
    final decl = _functionDecl(module, callee);
    if (module != _currentModule && !decl.isPub) {
      final shown = moduleName ?? module;
      throw CheckError('funkcja `$shown.$callee` jest prywatna', pos);
    }
    if (args.length != signature.paramTypes.length) {
      throw CheckError(
        'funkcja `$callee` oczekuje ${signature.paramTypes.length} argumentów, '
        'dostano ${args.length}',
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
    return _CheckedCall(signature.returnType, _mangledFreeName(module, callee));
  }

  FuncDecl _functionDecl(String module, String name) =>
      _allFunctions.firstWhere((func) =>
          func.receiver == null &&
          func.moduleName == module &&
          func.name == name);

  String _mangledFreeName(String module, String name) =>
      module.isEmpty ? name : '${module}_$name';

  KlinType _checkMethodCall(MethodCallExpr call) {
    final receiverType = _inferExpr(call.receiver);
    if (receiverType is! StructType) {
      throw CheckError(
          'metoda wymaga struktury, dostano `${receiverType.displayName}`',
          call.pos);
    }
    final signature = _methods['${receiverType.displayName}.${call.name}'];
    if (signature == null) {
      throw CheckError(
          'struktura `${receiverType.name}` nie ma metody `${call.name}`',
          call.pos);
    }
    if (receiverType.moduleName != _currentModule && !signature.isPub) {
      throw CheckError(
        'metoda `${receiverType.moduleName}.${receiverType.name}.${call.name}` jest prywatna',
        call.pos,
      );
    }
    if (signature.isMutReceiver) {
      if (call.receiver is! NameExpr) {
        throw CheckError(
            'metoda mutująca wymaga mutowalnej zmiennej', call.receiver.pos);
      }
      final receiver = call.receiver as NameExpr;
      final symbol = _scope.lookup(receiver.name);
      if (symbol == null || !symbol.isMut) {
        throw CheckError(
            'nie można wywołać metody mutującej na niemutowalnej zmiennej',
            call.receiver.pos);
      }
    }
    if (call.args.length != signature.paramTypes.length) {
      throw CheckError(
        'metoda `${call.name}` oczekuje ${signature.paramTypes.length} argumentów, dostano ${call.args.length}',
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
        throw CheckError('nieznana zmienna `${place.name}`', pos);
      if (!symbol.isMut) {
        throw CheckError(
            'nie można przypisać do niemutowalnej zmiennej `${place.name}`',
            pos);
      }
      place.isPtrReceiver = symbol.isPtrReceiver;
      return symbol.type;
    }
    if (place is FieldExpr) {
      final objectType = _inferExpr(place.object);
      if (objectType is ArrayType || objectType is SliceType) {
        throw CheckError('`len` jest tylko do odczytu', pos);
      }
      _requireMutableStructPlace(place.object, pos);
      return _inferExpr(place);
    }
    if (place is UnaryExpr && place.op == '*') {
      final pointer = _inferExpr(place.operand);
      if (pointer is! PtrType) {
        throw CheckError('dereferencja wymaga wskaźnika', pos);
      }
      if (!pointer.isMut) {
        throw CheckError('nie można pisać przez niemutowalny wskaźnik', pos);
      }
      return pointer.pointee;
    }
    if (place is IndexExpr) {
      final type = _inferExpr(place);
      _requireMutableArrayPlace(place.object, pos);
      return type;
    }
    throw CheckError('niepoprawny cel przypisania', pos);
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
            'nie można przypisać do pola niemutowalnej zmiennej', pos);
      }
      base.isPtrReceiver = symbol.isPtrReceiver;
      return;
    }
    throw CheckError(
        'nie można przypisać do pola niemutowalnego wyrażenia', pos);
  }

  void _requireMutableArrayPlace(Expr object, SourcePos pos) {
    final base = _unwrapGroups(object);
    if (base is NameExpr) {
      final symbol = _scope.lookup(base.name);
      if (symbol == null)
        throw CheckError('nieznana zmienna `${base.name}`', pos);
      if (!symbol.isMut) {
        throw CheckError('nie można przypisać do niemutowalnej tablicy', pos);
      }
      return;
    }
    throw CheckError('nie można przypisać przez niemutowalne wyrażenie', pos);
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

  /// Wnioskowanie bez kontekstu — może zwrócić typ untyped.
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
                'odczyt pola wymaga struktury, dostano `${objectType.displayName}`',
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
                'struktura `${objectType.name}` nie ma pola `$name`', pos);
          }
          return field.resolvedType!;
        }(),
      IndexExpr(:final object, :final index, :final pos) => () {
          final objectType = _inferExpr(object);
          final indexType = _defaultConcrete(_inferExpr(index), index.pos);
          if (indexType is! PrimType || !indexType.kind.isInteger) {
            throw CheckError('indeks wymaga typu całkowitego', index.pos);
          }
          _materialize(index, indexType);
          return switch (objectType) {
            ArrayType(:final elem) => elem,
            SliceType(:final elem) => elem,
            _ => throw CheckError(
                'indeksowanie wymaga tablicy lub slice, dostano `${objectType.displayName}`',
                pos,
              ),
          };
        }(),
      SliceFromExpr(:final array, :final pos) => () {
          final arrayType = _inferExpr(array);
          if (arrayType is! ArrayType || arrayType.elem is! PrimType) {
            throw CheckError('`[:]` wymaga tablicy typu prymitywnego', pos);
          }
          return SliceType(arrayType.elem as PrimType);
        }(),
      ArrayLitExpr(:final elements, :final pos) => () {
          if (elements.isEmpty) {
            throw CheckError('nie można wywnioskować typu pustej tablicy', pos);
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
                        'niezgodność typów elementów tablicy: `${elemType.displayName}` i `${nextType.displayName}`',
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
            throw CheckError('cast MVP obsługuje tylko typy wskaźnikowe', pos);
          }
          final source = _inferExpr(expr);
          if (source is! UntypedInt &&
              source is! PrimType &&
              source is! PtrType) {
            throw CheckError(
                'cast wskaźnika wymaga liczby całkowitej lub wskaźnika', pos);
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
            throw CheckError('nieznana struktura `$shown`', pos);
          }
          if (module != _currentModule && !struct.isPub) {
            final shown = moduleName ?? module;
            throw CheckError('struktura `$shown.$typeName` jest prywatna', pos);
          }
          if (namedFields != null) {
            if (namedFields.length != struct.fields.length) {
              throw CheckError(
                  'literał `$typeName` wymaga wszystkich pól', pos);
            }
            for (final field in struct.fields) {
              final value = namedFields[field.name];
              if (value == null)
                throw CheckError('brak pola `${field.name}` w literałe', pos);
              _expectAssignable(
                  field.resolvedType!, _inferExpr(value), value.pos);
              _materialize(value, field.resolvedType!);
            }
          } else {
            final values = positionalFields!;
            if (values.length != struct.fields.length) {
              throw CheckError(
                  'literał `$typeName` oczekuje ${struct.fields.length} pól',
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
              'wynik funkcji void `$callee` nie może być użyty jako wartość',
              pos,
            );
          }
          return call.type;
        }(),
      UnaryExpr(:final op, :final operand, :final pos) => () {
          if (op == '&') {
            if (!_isAddressablePlace(operand)) {
              throw CheckError('operator `&` wymaga miejsca w pamięci', pos);
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
              throw CheckError('dereferencja wymaga wskaźnika', pos);
            }
            return pointer.pointee;
          }
          if (op == '!') {
            final t = _inferExpr(operand);
            if (t is! PrimType || t.kind != PrimKind.bool_) {
              throw CheckError(
                'operator `!` wymaga typu `bool`, dostano `${t.displayName}`',
                pos,
              );
            }
            return const PrimType(PrimKind.bool_);
          }
          if (op != '-') {
            throw CheckError('nieznany operator unarny `$op`', pos);
          }
          final t = _inferExpr(operand);
          final concrete = _defaultConcrete(t, operand.pos);
          if (concrete is! PrimType ||
              !(concrete.kind.isInteger || concrete.kind.isFloat)) {
            throw CheckError(
              'operator `-` wymaga typu liczbowego, dostano `${concrete.displayName}`',
              pos,
            );
          }
          if (_isUnsigned(concrete.kind)) {
            throw CheckError(
              'operator `-` nie jest dozwolony dla typu bez znaku `${concrete.displayName}`',
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
        type is SliceType) expr.resolvedType = type;
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
      throw CheckError('nieznany operator `$op`', pos);
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
        'operator `$op` wymaga typów liczbowych, dostano `${concrete.displayName}`',
        pos,
      );
    }

    if (op == '%' && !concrete.kind.isInteger) {
      throw CheckError(
        'operator `%` wymaga typów całkowitych, dostano `${concrete.displayName}`',
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
          'operator `$op` nie jest dozwolony dla typu `bool`',
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
        'operator `$op` wymaga typów liczbowych, dostano `${concrete.displayName}`',
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
        'niezgodność typów: `${lt.displayName}` i `${rt.displayName}`',
        pos,
      );
    }
  }

  /// Ustawia konkretny typ na wyrażeniu (i rekurencyjnie na poddrzewie
  /// tam, gdzie były literały untyped).
  void _materialize(Expr expr, KlinType type) {
    // `cast(T, x)` zachowuje jawny typ T także gdy kontekst pozwala na
    // konwersję wskaźnika (np. odrzucenie volatile).
    if (expr is CastExpr) return;
    expr.resolvedType = type;
    switch (expr) {
      case UnaryExpr(:final operand, :final op):
        if (op != '&' && op != '*') _materialize(operand, type);
      case BinaryExpr(:final left, :final right, :final op):
        if (_cmpOps.contains(op)) {
          // Operandy porównania mają typ liczbowy; wynik bool jest na węźle.
          // Przy materializacji bool z góry nie schodzimy — typ operandów
          // został ustawiony w _inferComparison.
          break;
        }
        _materialize(left, type);
        _materialize(right, type);
      case GroupExpr(:final inner):
        _materialize(inner, type);
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
        'niezgodność typów: oczekiwano `${target.displayName}`, '
        'dostano `${source.displayName}`',
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
      VoidType() => throw CheckError(
          'nie można użyć wartości void w tym kontekście',
          pos,
        ),
      StrType() => throw CheckError(
          'nie można użyć napisu w tym kontekście',
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
