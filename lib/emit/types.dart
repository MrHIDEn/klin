part of '../emit_c.dart';

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
          (func.receiver != null
              ? _methodCName(
                  func.moduleName,
                  _receiverTypeName(func.receiver!),
                  func.name,
                )
              : func.associatedType != null
                  ? _methodCName(
                      func.moduleName,
                      _lastTypeSegment(func.associatedType!),
                      func.name,
                    )
                  : _freeCName(func.moduleName, func.name));
  final staticPrefix = !func.isPub &&
          func.name != 'main' &&
          codename == null &&
          func.body != null
      ? 'static '
      : '';
  return '$staticPrefix${_cType(returnType)} $name(${params.isEmpty ? 'void' : params.join(', ')})';
}

String _receiverTypeName(Receiver receiver) =>
    _lastTypeSegment(receiver.typeName);

String _lastTypeSegment(String typeName) =>
    typeName.contains('.') ? typeName.split('.').last : typeName;

String _cType(KlinType type) => switch (type) {
      PrimType(:final kind) => kind.cType,
      VoidType() => 'void',
      StrType() => 'const char*',
      StructType(:final moduleName, :final name) =>
        _structCName(moduleName, name),
      EnumType(:final moduleName, :final name) =>
        _enumCName(moduleName, name),
      PtrType(:final pointee, :final isVolatile) =>
        '${isVolatile ? 'volatile ' : ''}${_cType(pointee)} *',
      ArrayType(:final elem) => _cType(elem),
      SliceType(:final elem) => _sliceCName(elem),
      ResultType(:final ok) => _resultCName(ok),
      FnType(:final params, :final ret) => _fnTypedefName(FnType(params, ret)),
      _ => throw StateError('emit: type `${type.displayName}` has no C type'),
    };

String _cDecl(KlinType type, String name) => switch (type) {
      ArrayType(:final elem, :final len) => '${_cType(elem)} $name[$len]',
      FnType(:final params, :final ret) => () {
          final ps = params.isEmpty
              ? 'void'
              : params.map(_cType).join(', ');
          return '${_cType(ret)} (*$name)($ps)';
        }(),
      _ => '${_cType(type)} $name',
    };

String _fnTypedefName(FnType type) {
  final ps = type.params.map(_typeToken).join('_');
  final ret = _typeToken(type.ret);
  return ps.isEmpty ? 'klin_fn_void_$ret' : 'klin_fn_${ps}__$ret';
}

int _fnTypeDepth(FnType type) {
  var depth = 0;
  for (final p in type.params) {
    if (p is FnType) {
      final d = _fnTypeDepth(p) + 1;
      if (d > depth) depth = d;
    }
  }
  if (type.ret is FnType) {
    final d = _fnTypeDepth(type.ret as FnType) + 1;
    if (d > depth) depth = d;
  }
  return depth;
}

String _sliceCName(PrimType elem) => 'klin_slice_${elem.kind.klinName}';

void _collectSliceTypes(KlinType? type, Set<PrimType> output) {
  if (type case SliceType(:final elem)) output.add(elem);
  if (type case PtrType(:final pointee)) _collectSliceTypes(pointee, output);
  if (type case ArrayType(:final elem)) _collectSliceTypes(elem, output);
  if (type case ResultType(:final ok)) _collectSliceTypes(ok, output);
  if (type case FnType(:final params, :final ret)) {
    for (final p in params) {
      _collectSliceTypes(p, output);
    }
    _collectSliceTypes(ret, output);
  }
}

void _collectFnTypes(KlinType? type, Set<FnType> output) {
  if (type case FnType()) {
    output.add(type);
    for (final p in type.params) {
      _collectFnTypes(p, output);
    }
    _collectFnTypes(type.ret, output);
  }
  if (type case PtrType(:final pointee)) _collectFnTypes(pointee, output);
  if (type case ArrayType(:final elem)) _collectFnTypes(elem, output);
  if (type case ResultType(:final ok)) _collectFnTypes(ok, output);
}

void _collectResultTypes(KlinType? type, Set<ResultType> output) {
  if (type case ResultType(:final ok)) {
    output.add(type);
    _collectResultTypes(ok, output);
  }
  if (type case PtrType(:final pointee)) _collectResultTypes(pointee, output);
  if (type case ArrayType(:final elem)) _collectResultTypes(elem, output);
  if (type case FnType(:final params, :final ret)) {
    for (final p in params) {
      _collectResultTypes(p, output);
    }
    _collectResultTypes(ret, output);
  }
}

String _resultCName(KlinType ok) => 'klin_res_${_typeToken(ok)}';

String _typeToken(KlinType type) => switch (type) {
      PrimType(:final kind) => kind.klinName,
      VoidType() => 'void',
      StructType(:final moduleName, :final name) =>
        _structCName(moduleName, name),
      EnumType(:final moduleName, :final name) =>
        _enumCName(moduleName, name),
      SliceType(:final elem) => _sliceCName(elem),
      PtrType(:final pointee, :final isMut, :final isVolatile) =>
        '${isMut ? 'mut_' : ''}${isVolatile ? 'volatile_' : ''}ptr_${_typeToken(pointee)}',
      ArrayType(:final elem, :final len) => 'arr${len}_${_typeToken(elem)}',
      ResultType(:final ok) => 'res_${_typeToken(ok)}',
      FnType(:final params, :final ret) =>
        'fn_${params.map(_typeToken).join('_')}_${_typeToken(ret)}',
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
  int _interpTemp = 0;

  String nextReturnTemp() => 'klin_ret_${_returnTemp++}';
  String nextValueTemp() => 'klin_val_${_valueTemp++}';
  String nextInterpBuf() => '_klin_i${_interpTemp++}';
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

