import 'ast.dart';
import 'type.dart';

/// Emisja AST → jeden czytelny plik .c z dyrektywami `#line`.
String emitC(Program program, String sourcePath) {
  final buf = StringBuffer();
  buf.writeln('#include <stdio.h>');
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
        throw StateError('emit: brak typu pola `${field.name}`');
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
    _line(buf, func.pos.line, func.sourcePath ?? sourcePath);
    buf.writeln('${_functionHeader(func)} {');
    _emitBlock(
      buf,
      func.body,
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

String _functionHeader(FuncDecl func) {
  if (func.name == 'main') return 'int main(void)';
  final returnType = func.resolvedReturnType;
  if (returnType == null) {
    throw StateError('emit: brak typu zwracanego funkcji `${func.name}`');
  }
  final params = <String>[
    if (func.receiver case final receiver?)
      '${_cType(receiver.resolvedType!)}${receiver.isMut ? ' *' : ' '}${receiver.name}',
    ...func.params.map((param) {
      final type = param.resolvedType;
      if (type == null) {
        throw StateError('emit: brak typu parametru `${param.name}`');
      }
      return _cDecl(type, param.name);
    }),
  ];
  final name = func.name == 'main'
      ? 'main'
      : func.receiver == null
          ? _freeCName(func.moduleName, func.name)
          : _methodCName(
              func.moduleName,
              _receiverTypeName(func.receiver!),
              func.name,
            );
  final staticPrefix = !func.isPub && func.name != 'main' ? 'static ' : '';
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
      _ => throw StateError('emit: typ `${type.displayName}` nie ma typu C'),
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

String _resultCName(KlinType ok) => switch (ok) {
      PrimType(:final kind) => 'klin_res_${kind.klinName}',
      StructType(:final moduleName, :final name) =>
        'klin_res_${_structCName(moduleName, name)}',
      SliceType(:final elem) => 'klin_res_${_sliceCName(elem)}',
      PtrType() => 'klin_res_ptr',
      _ => throw StateError('emit: niedozwolony typ OK `${ok.displayName}`'),
    };

final class _DeferFrame {
  /// Ciała defer zarejestrowane w kolejności napotkania (nie z całego bloku z góry).
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
  final pad = '    ' * indent;
  if (value case PropagateExpr(:final result)) {
    final temp = _emitPropagate(
      buf,
      result: result,
      target: target,
      sourcePath: sourcePath,
      indent: indent,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
    buf.writeln('$pad$target = $temp.u.ok;');
    return;
  }
  if (value case OrExpr(:final result, :final fallback)) {
    final resultType = result.resolvedType;
    if (resultType is! ResultType) {
      throw StateError('emit: `or` bez typu wyniku');
    }
    final temp = state.nextValueTemp();
    buf.writeln('$pad${_cType(resultType)} $temp = ${_emitExpr(result)};');
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
  buf.writeln('$pad$target = ${_emitExpr(value)};');
}

String _emitPropagate(
  StringBuffer buf, {
  required Expr result,
  required String? target,
  required String sourcePath,
  required int indent,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
}) {
  final resultType = result.resolvedType;
  if (resultType is! ResultType) {
    throw StateError('emit: propagacja bez typu wyniku');
  }
  final pad = '    ' * indent;
  final temp = state.nextValueTemp();
  buf.writeln('$pad${_cType(resultType)} $temp = ${_emitExpr(result)};');
  buf.writeln('${pad}if ($temp.is_err) {');
  _emitExitCleanups(
    buf,
    state.deferStack,
    sourcePath,
    indent: indent + 1,
    bareReturnAsZero: bareReturnAsZero,
    returnCType: returnCType,
    state: state,
  );
  buf.writeln('${'    ' * (indent + 1)}return $temp;');
  buf.writeln('$pad}');
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
  switch (stmt) {
    case LetStmt(:final name, :final init, :final pos, :final resolvedType):
      _line(buf, pos.line, sourcePath);
      final ty = resolvedType;
      if (ty == null) {
        throw StateError('emit: brak typu dla `$name` — uruchom checker');
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
          buf.writeln('$pad${_cDecl(ty, name)} = ${_emitExpr(init)};');
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
          _ => throw StateError('emit: brak wartości domyślnej dla `$name`'),
        };
        buf.writeln('$pad${_cDecl(ty, name)} = $zero;');
      }

    case AssignStmt(:final target, :final value, :final pos):
      _line(buf, pos.line, sourcePath);
      if (value is OrExpr || value is PropagateExpr) {
        _emitValueAssignment(
          buf,
          target: _emitExpr(target),
          targetType: target.resolvedType!,
          value: value,
          sourcePath: sourcePath,
          indent: indent,
          bareReturnAsZero: bareReturnAsZero,
          returnCType: returnCType,
          state: state,
        );
      } else {
        buf.writeln('$pad${_emitExpr(target)} = ${_emitExpr(value)};');
      }

    case CallStmt(
        :final callee,
        :final args,
        :final pos,
        :final resolvedCallee
      ):
      _line(buf, pos.line, sourcePath);
      final argList = args.map(_emitExpr).join(', ');
      buf.writeln('$pad${resolvedCallee ?? callee}($argList);');

    case MethodCallStmt(:final call):
      _line(buf, call.pos.line, sourcePath);
      buf.writeln('$pad${_emitExpr(call)};');

    case IfStmt(:final cond, :final thenBlock, :final elseBranch, :final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('${pad}if (${_emitExpr(cond)}) {');
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
      buf.writeln('${pad}while (${_emitExpr(cond)}) {');
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
        throw StateError('emit: brak typu dla zmiennej pętli `$name`');
      }
      buf.writeln(
        '${pad}for (${ty.kind.cType} $name = ${_emitExpr(start)}; '
        '$name < ${_emitExpr(endExclusive)}; $name++) {',
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
          throw StateError('emit: brak typu dla init `$initName`');
        }
        return '${ty.kind.cType} $initName = ${_emitExpr(initExpr)}';
      }();
      final condPart = cond == null ? '' : _emitExpr(cond);
      final postPart = (postName != null && postExpr != null)
          ? '$postName = ${_emitExpr(postExpr)}'
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
          final propagated = _emitPropagate(
            buf,
            result: value.result,
            target: null,
            sourcePath: sourcePath,
            indent: indent,
            bareReturnAsZero: bareReturnAsZero,
            returnCType: returnCType,
            state: state,
          );
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
            ? _emitExpr(value)
            : returnCType.startsWith('klin_res_')
                ? '($returnCType){ .is_err = false, .u.ok = ${_emitExpr(value)} }'
                : _emitExpr(value);
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
      // Rejestruj dopiero w miejscu defer — wcześniejszy exit nie widzi późniejszych.
      if (state.deferStack.isEmpty) {
        throw StateError('emit: defer poza blokiem');
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
  if (elseBranch == null) {
    buf.writeln('$pad}');
    return;
  }
  if (elseBranch is IfStmt) {
    _line(buf, elseBranch.pos.line, sourcePath);
    buf.writeln('$pad} else if (${_emitExpr(elseBranch.cond)}) {');
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
  throw StateError('emit: nieoczekiwany else branch ${elseBranch.runtimeType}');
}

bool _exprIsPtrReceiver(Expr expr) {
  var current = expr;
  while (current is GroupExpr) {
    current = current.inner;
  }
  return current is NameExpr && current.isPtrReceiver;
}

String _emitExpr(Expr expr) {
  final raw = _emitExprRaw(expr);
  final from = expr.arrayToSliceFrom;
  if (from != null) {
    final elem = from.elem;
    if (elem is! PrimType) {
      throw StateError('emit: konwersja tablicy→slice wymaga prymitywu');
    }
    return '(${_sliceCName(elem)}){ $raw, ${from.len} }';
  }
  return raw;
}

String _emitExprRaw(Expr expr) {
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
            ? '${_emitExpr(object)}->$name'
            : '${_emitExpr(object)}.$name';
      }(),
    MethodCallExpr(
      :final receiver,
      :final args,
      :final mangledName,
      :final receiverByRef,
    ) =>
      '${mangledName ?? (throw StateError('emit: metoda bez manglingu'))}'
          '(${receiverByRef ? '&' : ''}${_emitExpr(receiver)}'
          '${args.isEmpty ? '' : ', ${args.map(_emitExpr).join(', ')}'})',
    StructLitExpr(
      :final resolvedType,
      :final typeName,
      :final namedFields,
      :final positionalFields
    ) =>
      namedFields != null
          ? '(${_cType(resolvedType ?? (throw StateError('emit: literał bez typu `$typeName`')))}){ ${namedFields.entries.map((entry) => '.${entry.key} = ${_emitExpr(entry.value)}').join(', ')} }'
          : '(${_cType(resolvedType ?? (throw StateError('emit: literał bez typu `$typeName`')))}){ ${positionalFields!.map(_emitExpr).join(', ')} }',
    CallExpr(:final callee, :final args, :final resolvedCallee) =>
      '${resolvedCallee ?? callee}(${args.map(_emitExpr).join(', ')})',
    UnaryExpr(:final op, :final operand) => '$op(${_emitExpr(operand)})',
    IndexExpr(:final object, :final index) => object.resolvedType is SliceType
        ? '${_emitExpr(object)}.ptr[${_emitExpr(index)}]'
        : '${_emitExpr(object)}[${_emitExpr(index)}]',
    SliceFromExpr(:final array) => () {
        final type = array.resolvedType;
        if (type is! ArrayType) {
          throw StateError('emit: `[:]` bez typu tablicy');
        }
        final elem = type.elem;
        if (elem is! PrimType) {
          throw StateError('emit: slice nieprymitywnego typu');
        }
        return '(${_sliceCName(elem)}){ ${_emitExpr(array)}, ${type.len} }';
      }(),
    ArrayLitExpr(:final elements) =>
      '{ ${elements.map(_emitExpr).join(', ')} }',
    CastExpr(:final resolvedType, :final expr) => () {
        if (resolvedType is! PtrType) {
          throw StateError('emit: cast bez typu wskaźnikowego');
        }
        return '(${_cType(resolvedType)})(uintptr_t)(${_emitExpr(expr)})';
      }(),
    BinaryExpr(:final left, :final op, :final right) =>
      '(${_emitExpr(left)} $op ${_emitExpr(right)})',
    GroupExpr(:final inner) => '(${_emitExpr(inner)})',
    ErrorExpr(:final code, :final resolvedType) => () {
        if (resolvedType is! ResultType) {
          throw StateError('emit: `error` bez typu wyniku');
        }
        return '(${_cType(resolvedType)}){ .is_err = true, .u.err = ${_emitExpr(code)} }';
      }(),
    PropagateExpr() ||
    OrExpr() =>
      throw StateError('emit: wynik `!` lub `or` wymaga kontekstu instrukcji'),
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
