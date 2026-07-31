import 'ast.dart';
import 'type.dart';

/// Emits the AST as one readable .c file with `#line` directives.
String emitC(Program program, String sourcePath) {
  final buf = StringBuffer();
  for (final include in _collectCIncludes(program)) {
    buf.writeln('#include $include');
  }
  buf.writeln('#include <stdint.h>');
  buf.writeln('#include <stddef.h>');
  buf.writeln('#include <stdbool.h>');
  buf.writeln();
  final sliceTypes = <PrimType>{};
  for (final struct in program.structs) {
    for (final field in struct.fields) {
      _collectSliceTypes(field.resolvedType, sliceTypes);
    }
  }
  for (final func in program.funcs) {
    _collectSliceTypes(func.resolvedReturnType, sliceTypes);
    for (final param in func.params) {
      _collectSliceTypes(param.resolvedType, sliceTypes);
    }
  }
  for (final type in sliceTypes) {
    final name = _sliceCName(type);
    buf.writeln(
        'typedef struct { ${type.kind.cType} *ptr; size_t len; } $name;');
  }
  if (sliceTypes.isNotEmpty) buf.writeln();
  for (final struct in program.structs) {
    _line(buf, struct.pos.line, struct.sourcePath ?? sourcePath);
    buf.writeln('typedef struct {');
    for (final field in struct.fields) {
      final type = field.resolvedType;
      if (type == null)
        throw StateError('emit: missing type for field `${field.name}`');
      buf.writeln('    ${_cDecl(type, field.name)};');
    }
    buf.writeln('} ${_structCName(struct.moduleName, struct.name)};');
    buf.writeln();
  }
  final resultTypes = <ResultType>{};
  for (final struct in program.structs) {
    for (final field in struct.fields) {
      _collectResultTypes(field.resolvedType, resultTypes);
    }
  }
  for (final func in program.funcs) {
    _collectResultTypes(func.resolvedReturnType, resultTypes);
    for (final param in func.params) {
      _collectResultTypes(param.resolvedType, resultTypes);
    }
  }
  for (final type in resultTypes) {
    final ok = _cType(type.ok);
    buf.writeln('typedef struct {');
    buf.writeln('    bool is_err;');
    buf.writeln('    union { $ok ok; int32_t err; } u;');
    buf.writeln('} ${_resultCName(type.ok)};');
    buf.writeln();
  }
  for (final func in program.funcs) {
    buf.writeln('${_functionHeader(func)};');
  }
  buf.writeln();
  for (final func in program.funcs) {
    if (func.body == null) continue;
    _line(buf, func.pos.line, func.sourcePath ?? sourcePath);
    buf.writeln('${_functionHeader(func)} {');
    _emitBlock(
      buf,
      func.body!,
      func.sourcePath ?? sourcePath,
      indent: 1,
      bareReturnAsZero: func.name == 'main',
      returnCType:
          func.name == 'main' ? 'int' : _cType(func.resolvedReturnType!),
      state: _EmitState(),
    );
    if (func.name == 'main') buf.writeln('    return 0;');
    buf.writeln('}');
    buf.writeln();
  }
  return buf.toString();
}

List<String> collectLinkAttrs(Program program) => [
      for (final decl in [...program.structs, ...program.funcs])
        for (final attr in switch (decl) {
          StructDecl(:final attrs) => attrs,
          FuncDecl(:final attrs) => attrs,
          _ => const <Attr>[],
        })
          if (attr.name == 'link' && attr.arg != null) attr.arg!,
    ];

Set<String> _collectCIncludes(Program program) {
  final includes = <String>{};
  for (final decl in [...program.structs, ...program.funcs]) {
    final attrs = switch (decl) {
      StructDecl(:final attrs) => attrs,
      FuncDecl(:final attrs) => attrs,
      _ => const <Attr>[],
    };
    for (final attr in attrs) {
      if (attr.name == 'cinclude') includes.add('"${attr.arg!}"');
    }
  }
  if (program.funcs.any(_callsStdio)) includes.add('<stdio.h>');
  return includes;
}

bool _callsStdio(FuncDecl func) =>
    func.body?.stmts.any(_stmtCallsStdio) ?? false;

bool _stmtCallsStdio(Stmt stmt) => switch (stmt) {
      CallStmt(:final callee, :final args) =>
        callee == 'puts' || callee == 'printf' || args.any(_exprCallsStdio),
      MethodCallStmt(:final call) => _exprCallsStdio(call),
      LetStmt(:final init) => init != null && _exprCallsStdio(init),
      AssignStmt(:final target, :final value) =>
        _exprCallsStdio(target) || _exprCallsStdio(value),
      IfStmt(:final cond, :final thenBlock, :final elseBranch) =>
        _exprCallsStdio(cond) ||
            thenBlock.stmts.any(_stmtCallsStdio) ||
            (elseBranch != null && _stmtCallsStdio(elseBranch)),
      WhileStmt(:final cond, :final body) =>
        _exprCallsStdio(cond) || body.stmts.any(_stmtCallsStdio),
      ForRangeStmt(:final start, :final endExclusive, :final body) =>
        _exprCallsStdio(start) ||
            _exprCallsStdio(endExclusive) ||
            body.stmts.any(_stmtCallsStdio),
      ForCStmt(:final initExpr, :final cond, :final postExpr, :final body) =>
        (initExpr != null && _exprCallsStdio(initExpr)) ||
            (cond != null && _exprCallsStdio(cond)) ||
            (postExpr != null && _exprCallsStdio(postExpr)) ||
            body.stmts.any(_stmtCallsStdio),
      ReturnStmt(:final value) => value != null && _exprCallsStdio(value),
      DeferStmt(:final body) => _stmtCallsStdio(body),
      BlockStmt(:final block) => block.stmts.any(_stmtCallsStdio),
      _ => false,
    };

bool _exprCallsStdio(Expr expr) => switch (expr) {
      CallExpr(:final callee, :final args) =>
        callee == 'puts' || callee == 'printf' || args.any(_exprCallsStdio),
      MethodCallExpr(:final receiver, :final args) =>
        _exprCallsStdio(receiver) || args.any(_exprCallsStdio),
      FieldExpr(:final object) => _exprCallsStdio(object),
      IndexExpr(:final object, :final index) =>
        _exprCallsStdio(object) || _exprCallsStdio(index),
      SliceFromExpr(:final array) => _exprCallsStdio(array),
      ArrayLitExpr(:final elements) => elements.any(_exprCallsStdio),
      CastExpr(:final expr) => _exprCallsStdio(expr),
      BinaryExpr(:final left, :final right) =>
        _exprCallsStdio(left) || _exprCallsStdio(right),
      UnaryExpr(:final operand) => _exprCallsStdio(operand),
      GroupExpr(:final inner) => _exprCallsStdio(inner),
      ErrorExpr(:final code) => _exprCallsStdio(code),
      PropagateExpr(:final result) => _exprCallsStdio(result),
      OrExpr(:final result, :final fallback) => _exprCallsStdio(result) ||
          fallback.stmts.any(_stmtCallsStdio) ||
          _exprCallsStdio(fallback.value),
      StructLitExpr(:final namedFields, :final positionalFields) =>
        namedFields?.values.any(_exprCallsStdio) ??
            positionalFields!.any(_exprCallsStdio),
      _ => false,
    };

String _functionHeader(FuncDecl func) {
  if (func.name == 'main') return 'int main(void)';
  final returnType = func.resolvedReturnType;
  if (returnType == null) {
    throw StateError('emit: missing return type for function `${func.name}`');
  }
  final params = <String>[
    if (func.receiver case final receiver?)
      '${_cType(receiver.resolvedType!)}${receiver.isMut ? ' *' : ' '}${receiver.name}',
    ...func.params.map((param) {
      final type = param.resolvedType;
      if (type == null) {
        throw StateError('emit: missing type for parameter `${param.name}`');
      }
      return _cDecl(type, param.name);
    }),
  ];
  final codename = func.attrs
      .where((attr) => attr.name == 'codename')
      .map((attr) => attr.arg!)
      .firstOrNull;
  final name = func.name == 'main'
      ? 'main'
      : codename ??
          (func.receiver == null
              ? _freeCName(func.moduleName, func.name)
              : _methodCName(
                  func.moduleName,
                  _receiverTypeName(func.receiver!),
                  func.name,
                ));
  final staticPrefix = !func.isPub &&
          func.name != 'main' &&
          codename == null &&
          func.body != null
      ? 'static '
      : '';
  return '$staticPrefix${_cType(returnType)} $name(${params.isEmpty ? 'void' : params.join(', ')})';
}

String _receiverTypeName(Receiver receiver) => receiver.typeName.contains('.')
    ? receiver.typeName.split('.').last
    : receiver.typeName;

String _cType(KlinType type) => switch (type) {
      PrimType(:final kind) => kind.cType,
      VoidType() => 'void',
      StrType() => 'const char*',
      StructType(:final moduleName, :final name) =>
        _structCName(moduleName, name),
      PtrType(:final pointee, :final isVolatile) =>
        '${isVolatile ? 'volatile ' : ''}${_cType(pointee)} *',
      ArrayType(:final elem) => _cType(elem),
      SliceType(:final elem) => _sliceCName(elem),
      ResultType(:final ok) => _resultCName(ok),
      _ => throw StateError('emit: type `${type.displayName}` has no C type'),
    };

String _cDecl(KlinType type, String name) => switch (type) {
      ArrayType(:final elem, :final len) => '${_cType(elem)} $name[$len]',
      _ => '${_cType(type)} $name',
    };

String _sliceCName(PrimType elem) => 'klin_slice_${elem.kind.klinName}';

void _collectSliceTypes(KlinType? type, Set<PrimType> output) {
  if (type case SliceType(:final elem)) output.add(elem);
  if (type case PtrType(:final pointee)) _collectSliceTypes(pointee, output);
  if (type case ArrayType(:final elem)) _collectSliceTypes(elem, output);
  if (type case ResultType(:final ok)) _collectSliceTypes(ok, output);
}

void _collectResultTypes(KlinType? type, Set<ResultType> output) {
  if (type case ResultType(:final ok)) {
    output.add(type);
    _collectResultTypes(ok, output);
  }
  if (type case PtrType(:final pointee)) _collectResultTypes(pointee, output);
  if (type case ArrayType(:final elem)) _collectResultTypes(elem, output);
}

String _resultCName(KlinType ok) => 'klin_res_${_typeToken(ok)}';

String _typeToken(KlinType type) => switch (type) {
      PrimType(:final kind) => kind.klinName,
      StructType(:final moduleName, :final name) =>
        _structCName(moduleName, name),
      SliceType(:final elem) => _sliceCName(elem),
      PtrType(:final pointee, :final isMut, :final isVolatile) =>
        '${isMut ? 'mut_' : ''}${isVolatile ? 'volatile_' : ''}ptr_${_typeToken(pointee)}',
      ArrayType(:final elem, :final len) => 'arr${len}_${_typeToken(elem)}',
      ResultType(:final ok) => 'res_${_typeToken(ok)}',
      StrType() => 'str',
      _ =>
        throw StateError('emit: missing type token for `${type.displayName}`'),
    };

final class _DeferFrame {
  /// Defer bodies registered in encounter order, not from the whole block in advance.
  final List<Stmt> defers = [];
  final bool isLoopBody;

  _DeferFrame({this.isLoopBody = false});
}

final class _EmitState {
  final List<_DeferFrame> deferStack = [];
  int _returnTemp = 0;
  int _valueTemp = 0;

  String nextReturnTemp() => 'klin_ret_${_returnTemp++}';
  String nextValueTemp() => 'klin_val_${_valueTemp++}';
}

final class _ExprCtx {
  final StringBuffer buf;
  final String sourcePath;
  final int indent;
  final bool bareReturnAsZero;
  final String returnCType;
  final _EmitState state;

  _ExprCtx({
    required this.buf,
    required this.sourcePath,
    required this.indent,
    required this.bareReturnAsZero,
    required this.returnCType,
    required this.state,
  });
}

void _emitValueAssignment(
  StringBuffer buf, {
  required String target,
  required KlinType targetType,
  required Expr value,
  required String sourcePath,
  required int indent,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
}) {
  final ctx = _ExprCtx(
    buf: buf,
    sourcePath: sourcePath,
    indent: indent,
    bareReturnAsZero: bareReturnAsZero,
    returnCType: returnCType,
    state: state,
  );
  final pad = '    ' * indent;
  if (value case PropagateExpr(:final result)) {
    final temp = _emitPropagate(result, ctx);
    buf.writeln('$pad$target = $temp.u.ok;');
    return;
  }
  if (value case OrExpr(:final result, :final fallback)) {
    final resultType = result.resolvedType;
    if (resultType is! ResultType) {
      throw StateError('emit: `or` without a result type');
    }
    final temp = state.nextValueTemp();
    buf.writeln('$pad${_cType(resultType)} $temp = ${_emitExpr(result, ctx)};');
    buf.writeln('${pad}if ($temp.is_err) {');
    final innerPad = '    ' * (indent + 1);
    buf.writeln('${innerPad}int32_t err = $temp.u.err;');
    for (final stmt in fallback.stmts) {
      _emitStmt(
        buf,
        stmt,
        sourcePath,
        indent: indent + 1,
        pad: innerPad,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
      );
    }
    _emitValueAssignment(
      buf,
      target: target,
      targetType: targetType,
      value: fallback.value,
      sourcePath: sourcePath,
      indent: indent + 1,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
    buf.writeln('$pad} else {');
    buf.writeln('${innerPad}$target = $temp.u.ok;');
    buf.writeln('$pad}');
    return;
  }
  buf.writeln('$pad$target = ${_emitExpr(value, ctx)};');
}

String _emitPropagate(Expr result, _ExprCtx ctx) {
  final resultType = result.resolvedType;
  if (resultType is! ResultType) {
    throw StateError('emit: propagation without a result type');
  }
  final pad = '    ' * ctx.indent;
  final temp = ctx.state.nextValueTemp();
  ctx.buf
      .writeln('$pad${_cType(resultType)} $temp = ${_emitExpr(result, ctx)};');
  ctx.buf.writeln('${pad}if ($temp.is_err) {');
  _emitExitCleanups(
    ctx.buf,
    ctx.state.deferStack,
    ctx.sourcePath,
    indent: ctx.indent + 1,
    bareReturnAsZero: ctx.bareReturnAsZero,
    returnCType: ctx.returnCType,
    state: ctx.state,
  );
  ctx.buf.writeln('${'    ' * (ctx.indent + 1)}return $temp;');
  ctx.buf.writeln('$pad}');
  return temp;
}

void _emitBlock(
  StringBuffer buf,
  Block block,
  String sourcePath, {
  required int indent,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
  bool isLoopBody = false,
}) {
  final pad = '    ' * indent;
  final frame = _DeferFrame(isLoopBody: isLoopBody);
  state.deferStack.add(frame);
  for (final stmt in block.stmts) {
    _emitStmt(
      buf,
      stmt,
      sourcePath,
      indent: indent,
      pad: pad,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
  }
  _emitFrameCleanups(
    buf,
    frame,
    sourcePath,
    indent: indent,
    bareReturnAsZero: bareReturnAsZero,
    returnCType: returnCType,
    state: state,
  );
  state.deferStack.removeLast();
}

void _emitStmt(
  StringBuffer buf,
  Stmt stmt,
  String sourcePath, {
  required int indent,
  required String pad,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
}) {
  final ctx = _ExprCtx(
    buf: buf,
    sourcePath: sourcePath,
    indent: indent,
    bareReturnAsZero: bareReturnAsZero,
    returnCType: returnCType,
    state: state,
  );
  switch (stmt) {
    case AsmStmt(:final code, :final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('${pad}asm volatile("${_escapeC(code)}");');

    case LetStmt(:final name, :final init, :final pos, :final resolvedType):
      _line(buf, pos.line, sourcePath);
      final ty = resolvedType;
      if (ty == null) {
        throw StateError('emit: missing type for `$name` — run the checker');
      }
      if (init != null) {
        if (init is OrExpr || init is PropagateExpr) {
          buf.writeln('$pad${_cDecl(ty, name)};');
          _emitValueAssignment(
            buf,
            target: name,
            targetType: ty,
            value: init,
            sourcePath: sourcePath,
            indent: indent,
            bareReturnAsZero: bareReturnAsZero,
            returnCType: returnCType,
            state: state,
          );
        } else {
          buf.writeln('$pad${_cDecl(ty, name)} = ${_emitExpr(init, ctx)};');
        }
      } else {
        final zero = switch (ty) {
          PrimType(:final kind) => kind.cZero,
          PtrType() => 'NULL',
          ArrayType() => '{0}',
          SliceType() => '{ NULL, 0 }',
          StructType() => '{0}',
          StrType() => 'NULL',
          ResultType() => '{0}',
          _ => throw StateError('emit: missing default value for `$name`'),
        };
        buf.writeln('$pad${_cDecl(ty, name)} = $zero;');
      }

    case AssignStmt(:final target, :final value, :final pos):
      _line(buf, pos.line, sourcePath);
      if (value is OrExpr || value is PropagateExpr) {
        _emitValueAssignment(
          buf,
          target: _emitExpr(target, ctx),
          targetType: target.resolvedType!,
          value: value,
          sourcePath: sourcePath,
          indent: indent,
          bareReturnAsZero: bareReturnAsZero,
          returnCType: returnCType,
          state: state,
        );
      } else {
        buf.writeln(
            '$pad${_emitExpr(target, ctx)} = ${_emitExpr(value, ctx)};');
      }

    case CallStmt(
        :final callee,
        :final args,
        :final pos,
        :final resolvedCallee
      ):
      _line(buf, pos.line, sourcePath);
      final argList = args.map((arg) => _emitExpr(arg, ctx)).join(', ');
      buf.writeln('$pad${resolvedCallee ?? callee}($argList);');

    case MethodCallStmt(:final call):
      _line(buf, call.pos.line, sourcePath);
      buf.writeln('$pad${_emitExpr(call, ctx)};');

    case IfStmt(:final cond, :final thenBlock, :final elseBranch, :final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('${pad}if (${_emitExpr(cond, ctx)}) {');
      _emitBlock(
        buf,
        thenBlock,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
      );
      _emitElse(
        buf,
        elseBranch,
        sourcePath,
        indent: indent,
        pad: pad,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
      );

    case WhileStmt(:final cond, :final body, :final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('${pad}while (${_emitExpr(cond, ctx)}) {');
      _emitBlock(
        buf,
        body,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
        isLoopBody: true,
      );
      buf.writeln('$pad}');

    case ForRangeStmt(
        :final name,
        :final start,
        :final endExclusive,
        :final body,
        :final pos,
        :final resolvedType
      ):
      _line(buf, pos.line, sourcePath);
      final ty = resolvedType;
      if (ty is! PrimType) {
        throw StateError('emit: missing type for loop variable `$name`');
      }
      buf.writeln(
        '${pad}for (${ty.kind.cType} $name = ${_emitExpr(start, ctx)}; '
        '$name < ${_emitExpr(endExclusive, ctx)}; $name++) {',
      );
      _emitBlock(
        buf,
        body,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
        isLoopBody: true,
      );
      buf.writeln('$pad}');

    case ForCStmt(
        :final initName,
        :final initExpr,
        :final cond,
        :final postName,
        :final postExpr,
        :final body,
        :final pos,
        :final resolvedInitType
      ):
      _line(buf, pos.line, sourcePath);
      final initPart = () {
        if (initName == null || initExpr == null) return '';
        final ty = resolvedInitType;
        if (ty is! PrimType) {
          throw StateError('emit: missing type for initializer `$initName`');
        }
        return '${ty.kind.cType} $initName = ${_emitExpr(initExpr, ctx)}';
      }();
      final condPart = cond == null ? '' : _emitExpr(cond, ctx);
      final postPart = (postName != null && postExpr != null)
          ? '$postName = ${_emitExpr(postExpr, ctx)}'
          : '';
      buf.writeln('${pad}for ($initPart; $condPart; $postPart) {');
      _emitBlock(
        buf,
        body,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
        isLoopBody: true,
      );
      buf.writeln('$pad}');

    case ReturnStmt(:final value, :final pos):
      _line(buf, pos.line, sourcePath);
      if (value == null) {
        _emitExitCleanups(
          buf,
          state.deferStack,
          sourcePath,
          indent: indent,
          bareReturnAsZero: bareReturnAsZero,
          returnCType: returnCType,
          state: state,
        );
        buf.writeln(bareReturnAsZero ? '${pad}return 0;' : '${pad}return;');
      } else {
        if (value is PropagateExpr) {
          final propagated = _emitPropagate(value.result, ctx);
          final resultType = value.result.resolvedType! as ResultType;
          final temp = state.nextReturnTemp();
          buf.writeln(
            '$pad$returnCType $temp = (${_cType(resultType)}){ '
            '.is_err = false, .u.ok = $propagated.u.ok };',
          );
          _emitExitCleanups(
            buf,
            state.deferStack,
            sourcePath,
            indent: indent,
            bareReturnAsZero: bareReturnAsZero,
            returnCType: returnCType,
            state: state,
          );
          buf.writeln('${pad}return $temp;');
          return;
        }
        final temp = state.nextReturnTemp();
        final valueType = value.resolvedType;
        final returnValue = valueType is ResultType
            ? _emitExpr(value, ctx)
            : returnCType.startsWith('klin_res_')
                ? '($returnCType){ .is_err = false, .u.ok = ${_emitExpr(value, ctx)} }'
                : _emitExpr(value, ctx);
        buf.writeln('$pad$returnCType $temp = $returnValue;');
        _emitExitCleanups(
          buf,
          state.deferStack,
          sourcePath,
          indent: indent,
          bareReturnAsZero: bareReturnAsZero,
          returnCType: returnCType,
          state: state,
        );
        buf.writeln('${pad}return $temp;');
      }

    case BreakStmt(:final pos):
      _line(buf, pos.line, sourcePath);
      _emitLoopExitCleanups(
        buf,
        state,
        sourcePath,
        indent: indent,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
      );
      buf.writeln('${pad}break;');

    case ContinueStmt(:final pos):
      _line(buf, pos.line, sourcePath);
      _emitLoopExitCleanups(
        buf,
        state,
        sourcePath,
        indent: indent,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
      );
      buf.writeln('${pad}continue;');

    case DeferStmt(:final body):
      // Register at the defer site: earlier exits must not see later defers.
      if (state.deferStack.isEmpty) {
        throw StateError('emit: `defer` outside a block');
      }
      state.deferStack.last.defers.add(body);

    case BlockStmt(:final block):
      _line(buf, block.pos.line, sourcePath);
      buf.writeln('$pad{');
      _emitBlock(
        buf,
        block,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
      );
      buf.writeln('$pad}');
  }
}

void _emitFrameCleanups(
  StringBuffer buf,
  _DeferFrame frame,
  String sourcePath, {
  required int indent,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
}) {
  final pad = '    ' * indent;
  for (final body in frame.defers.reversed) {
    _emitStmt(
      buf,
      body,
      sourcePath,
      indent: indent,
      pad: pad,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
  }
}

void _emitExitCleanups(
  StringBuffer buf,
  Iterable<_DeferFrame> frames,
  String sourcePath, {
  required int indent,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
}) {
  for (final frame in frames.toList().reversed) {
    _emitFrameCleanups(
      buf,
      frame,
      sourcePath,
      indent: indent,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
  }
}

void _emitLoopExitCleanups(
  StringBuffer buf,
  _EmitState state,
  String sourcePath, {
  required int indent,
  required bool bareReturnAsZero,
  required String returnCType,
}) {
  final frames = <_DeferFrame>[];
  for (final frame in state.deferStack.reversed) {
    frames.add(frame);
    if (frame.isLoopBody) break;
  }
  _emitExitCleanups(
    buf,
    frames.reversed,
    sourcePath,
    indent: indent,
    bareReturnAsZero: bareReturnAsZero,
    returnCType: returnCType,
    state: state,
  );
}

void _emitElse(
  StringBuffer buf,
  Stmt? elseBranch,
  String sourcePath, {
  required int indent,
  required String pad,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
}) {
  final ctx = _ExprCtx(
    buf: buf,
    sourcePath: sourcePath,
    indent: indent,
    bareReturnAsZero: bareReturnAsZero,
    returnCType: returnCType,
    state: state,
  );
  if (elseBranch == null) {
    buf.writeln('$pad}');
    return;
  }
  if (elseBranch is IfStmt) {
    _line(buf, elseBranch.pos.line, sourcePath);
    buf.writeln('$pad} else if (${_emitExpr(elseBranch.cond, ctx)}) {');
    _emitBlock(
      buf,
      elseBranch.thenBlock,
      sourcePath,
      indent: indent + 1,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
    _emitElse(
      buf,
      elseBranch.elseBranch,
      sourcePath,
      indent: indent,
      pad: pad,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
    return;
  }
  if (elseBranch is BlockStmt) {
    buf.writeln('$pad} else {');
    _emitBlock(
      buf,
      elseBranch.block,
      sourcePath,
      indent: indent + 1,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
    buf.writeln('$pad}');
    return;
  }
  throw StateError('emit: unexpected else branch ${elseBranch.runtimeType}');
}

bool _exprIsPtrReceiver(Expr expr) {
  var current = expr;
  while (current is GroupExpr) {
    current = current.inner;
  }
  return current is NameExpr && current.isPtrReceiver;
}

String _emitExpr(Expr expr, _ExprCtx ctx) {
  final raw = _emitExprRaw(expr, ctx);
  final from = expr.arrayToSliceFrom;
  if (from != null) {
    final elem = from.elem;
    if (elem is! PrimType) {
      throw StateError(
          'emit: array-to-slice conversion requires a primitive type');
    }
    return '(${_sliceCName(elem)}){ $raw, ${from.len} }';
  }
  return raw;
}

String _emitExprRaw(Expr expr, _ExprCtx ctx) {
  return switch (expr) {
    IntLit(:final lexeme) => lexeme.replaceAll('_', ''),
    FloatLit(:final lexeme) => lexeme.replaceAll('_', ''),
    BoolLit(:final value) => value ? 'true' : 'false',
    StringLit(:final value) => '"${_escapeC(value)}"',
    NameExpr(:final name) => name,
    FieldExpr(:final object, :final name) => () {
        final objectType = object.resolvedType;
        if (name == 'len' && objectType is ArrayType) {
          return objectType.len.toString();
        }
        return _exprIsPtrReceiver(object)
            ? '${_emitExpr(object, ctx)}->$name'
            : '${_emitExpr(object, ctx)}.$name';
      }(),
    MethodCallExpr(
      :final receiver,
      :final args,
      :final mangledName,
      :final receiverByRef,
    ) =>
      '${mangledName ?? (throw StateError('emit: method without mangling'))}'
          '(${receiverByRef ? '&' : ''}${_emitExpr(receiver, ctx)}'
          '${args.isEmpty ? '' : ', ${args.map((arg) => _emitExpr(arg, ctx)).join(', ')}'})',
    StructLitExpr(
      :final resolvedType,
      :final typeName,
      :final namedFields,
      :final positionalFields
    ) =>
      namedFields != null
          ? '(${_cType(resolvedType ?? (throw StateError('emit: literal without type `$typeName`')))}){ ${namedFields.entries.map((entry) => '.${entry.key} = ${_emitExpr(entry.value, ctx)}').join(', ')} }'
          : '(${_cType(resolvedType ?? (throw StateError('emit: literal without type `$typeName`')))}){ ${positionalFields!.map((field) => _emitExpr(field, ctx)).join(', ')} }',
    CallExpr(:final callee, :final args, :final resolvedCallee) =>
      '${resolvedCallee ?? callee}(${args.map((arg) => _emitExpr(arg, ctx)).join(', ')})',
    UnaryExpr(:final op, :final operand) => '$op(${_emitExpr(operand, ctx)})',
    IndexExpr(:final object, :final index) => object.resolvedType is SliceType
        ? '${_emitExpr(object, ctx)}.ptr[${_emitExpr(index, ctx)}]'
        : '${_emitExpr(object, ctx)}[${_emitExpr(index, ctx)}]',
    SliceFromExpr(:final array) => () {
        final type = array.resolvedType;
        if (type is! ArrayType) {
          throw StateError('emit: `[:]` without an array type');
        }
        final elem = type.elem;
        if (elem is! PrimType) {
          throw StateError('emit: slice has a non-primitive element type');
        }
        return '(${_sliceCName(elem)}){ ${_emitExpr(array, ctx)}, ${type.len} }';
      }(),
    ArrayLitExpr(:final elements) =>
      '{ ${elements.map((element) => _emitExpr(element, ctx)).join(', ')} }',
    CastExpr(:final resolvedType, :final expr) => () {
        if (resolvedType is! PtrType) {
          throw StateError('emit: cast without pointer type');
        }
        return '(${_cType(resolvedType)})(uintptr_t)(${_emitExpr(expr, ctx)})';
      }(),
    BinaryExpr(:final left, :final op, :final right) =>
      '(${_emitExpr(left, ctx)} $op ${_emitExpr(right, ctx)})',
    GroupExpr(:final inner) => '(${_emitExpr(inner, ctx)})',
    ErrorExpr(:final code, :final resolvedType) => () {
        if (resolvedType is! ResultType) {
          throw StateError('emit: `error` without a result type');
        }
        return '(${_cType(resolvedType)}){ .is_err = true, .u.err = ${_emitExpr(code, ctx)} }';
      }(),
    PropagateExpr(:final result) => () {
        final temp = _emitPropagate(result, ctx);
        return '$temp.u.ok';
      }(),
    OrExpr(:final resolvedType) => () {
        final outType = resolvedType;
        if (outType == null) {
          throw StateError('emit: `or` without an expression result type');
        }
        final out = ctx.state.nextValueTemp();
        final pad = '    ' * ctx.indent;
        ctx.buf.writeln('$pad${_cType(outType)} $out;');
        _emitValueAssignment(
          ctx.buf,
          target: out,
          targetType: outType,
          value: expr,
          sourcePath: ctx.sourcePath,
          indent: ctx.indent,
          bareReturnAsZero: ctx.bareReturnAsZero,
          returnCType: ctx.returnCType,
          state: ctx.state,
        );
        return out;
      }(),
  };
}

String _structCName(String module, String name) =>
    module.isEmpty ? name : '${module}_$name';

String _freeCName(String module, String name) =>
    module.isEmpty ? name : '${module}_$name';

String _methodCName(String module, String type, String method) =>
    module.isEmpty ? '${type}_$method' : '${module}_${type}_$method';

void _line(StringBuffer buf, int line, String path) {
  buf.writeln('#line $line "${_escapeC(path)}"');
}

String _escapeC(String s) {
  final out = StringBuffer();
  for (final cu in s.runes) {
    switch (cu) {
      case 0x0A: // \n
        out.write('\\n');
      case 0x09: // \t
        out.write('\\t');
      case 0x22: // "
        out.write('\\"');
      case 0x5C: // \
        out.write('\\\\');
      default:
        if (cu < 0x20 || cu == 0x7F) {
          out.write('\\x${cu.toRadixString(16).padLeft(2, '0')}');
        } else {
          out.writeCharCode(cu);
        }
    }
  }
  return out.toString();
}
