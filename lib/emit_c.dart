import 'ast.dart';
import 'type.dart';

part 'emit/analyze.dart';
part 'emit/host.dart';
part 'emit/interp.dart';
part 'emit/types.dart';
part 'emit/stmt.dart';
part 'emit/expr.dart';

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
  final fnTypes = <FnType>{};
  for (final struct in program.structs) {
    for (final field in struct.fields) {
      _collectFnTypes(field.resolvedType, fnTypes);
    }
  }
  for (final func in program.funcs) {
    _collectFnTypes(func.resolvedReturnType, fnTypes);
    for (final param in func.params) {
      _collectFnTypes(param.resolvedType, fnTypes);
    }
  }
  final orderedFnTypes = fnTypes.toList()
    ..sort((a, b) => _fnTypeDepth(a).compareTo(_fnTypeDepth(b)));
  for (final type in orderedFnTypes) {
    final name = _fnTypedefName(type);
    final ps = type.params.isEmpty
        ? 'void'
        : type.params.map(_cType).join(', ');
    buf.writeln('typedef ${_cType(type.ret)} (*$name)($ps);');
  }
  if (orderedFnTypes.isNotEmpty) buf.writeln();
  if (_programNeedsTrimFrac(program)) {
    buf.writeln('#include <stdio.h>');
    buf.writeln('#include <string.h>');
    buf.writeln(
        'static void klin_fmt_trim_frac(char *buf, size_t n, double v, int max_frac) {');
    buf.writeln('    snprintf(buf, n, "%.*f", max_frac, v);');
    buf.writeln('    size_t len = strlen(buf);');
    buf.writeln('    while (len > 0 && buf[len - 1] == \'0\') {');
    buf.writeln('        buf[--len] = \'\\0\';');
    buf.writeln('    }');
    buf.writeln('    if (len > 0 && buf[len - 1] == \'.\') {');
    buf.writeln('        buf[--len] = \'\\0\';');
    buf.writeln('    }');
    buf.writeln('}');
    buf.writeln();
  }
  if (_programNeedsTimeHost(program)) {
    _emitTimeHostHelpers(buf);
  }
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
  if (_programNeedsMemHost(program)) {
    _emitMemHostHelpers(buf, program);
  }
  for (final func in program.funcs) {
    // `@[cheader]` + `@[cimport]`: prototype lives in a C header (`cinclude`).
    if (func.attrs.any((a) => a.name == 'cheader')) continue;
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

/// Emits a C header with prototypes for `@[cexport]` functions (`--emit-h`).
String emitH(Program program, String sourcePath) {
  final exports =
      program.funcs.where((f) => f.attrs.any((a) => a.name == 'cexport')).toList();
  final guard = _headerGuard(sourcePath);
  final buf = StringBuffer();
  buf.writeln('/* Generated by klin --emit-h — do not edit. */');
  buf.writeln('#ifndef $guard');
  buf.writeln('#define $guard');
  buf.writeln();
  buf.writeln('#include <stdint.h>');
  buf.writeln('#include <stddef.h>');
  buf.writeln('#include <stdbool.h>');
  buf.writeln();

  final sliceTypes = <PrimType>{};
  final resultTypes = <ResultType>{};
  final structKeys = <String>{};
  void collectSig(KlinType? type) {
    _collectSliceTypes(type, sliceTypes);
    _collectResultTypes(type, resultTypes);
    _collectStructKeys(type, structKeys);
  }

  for (final func in exports) {
    collectSig(func.resolvedReturnType);
    for (final param in func.params) {
      collectSig(param.resolvedType);
    }
    if (func.receiver case final receiver?) {
      collectSig(receiver.resolvedType);
    }
  }

  // Fixed-point: nested struct fields may add keys (and their deps) later.
  var growing = true;
  while (growing) {
    final before = structKeys.length + sliceTypes.length + resultTypes.length;
    for (final struct in program.structs) {
      final key = '${struct.moduleName}.${struct.name}';
      if (!structKeys.contains(key)) continue;
      for (final field in struct.fields) {
        collectSig(field.resolvedType);
      }
    }
    growing =
        structKeys.length + sliceTypes.length + resultTypes.length > before;
  }

  for (final type in sliceTypes) {
    buf.writeln(
        'typedef struct { ${type.kind.cType} *ptr; size_t len; } ${_sliceCName(type)};');
  }
  if (sliceTypes.isNotEmpty) buf.writeln();

  // Emit structs so field dependencies appear before dependents.
  final emittedStructs = <String>{};
  while (emittedStructs.length < structKeys.length) {
    var progress = false;
    for (final struct in program.structs) {
      final key = '${struct.moduleName}.${struct.name}';
      if (!structKeys.contains(key) || emittedStructs.contains(key)) continue;
      final fieldDeps = <String>{};
      for (final field in struct.fields) {
        _collectStructKeys(field.resolvedType, fieldDeps);
      }
      if (!fieldDeps
          .every((dep) => !structKeys.contains(dep) || emittedStructs.contains(dep))) {
        continue;
      }
      _line(buf, struct.pos.line, struct.sourcePath ?? sourcePath);
      buf.writeln('typedef struct {');
      for (final field in struct.fields) {
        final type = field.resolvedType;
        if (type == null) {
          throw StateError('emit: missing type for field `${field.name}`');
        }
        buf.writeln('    ${_cDecl(type, field.name)};');
      }
      buf.writeln('} ${_structCName(struct.moduleName, struct.name)};');
      buf.writeln();
      emittedStructs.add(key);
      progress = true;
    }
    if (!progress) {
      // Cycle or unresolved dep — fall back to declaration order (like emitC).
      for (final struct in program.structs) {
        final key = '${struct.moduleName}.${struct.name}';
        if (!structKeys.contains(key) || emittedStructs.contains(key)) continue;
        _line(buf, struct.pos.line, struct.sourcePath ?? sourcePath);
        buf.writeln('typedef struct {');
        for (final field in struct.fields) {
          final type = field.resolvedType;
          if (type == null) {
            throw StateError('emit: missing type for field `${field.name}`');
          }
          buf.writeln('    ${_cDecl(type, field.name)};');
        }
        buf.writeln('} ${_structCName(struct.moduleName, struct.name)};');
        buf.writeln();
        emittedStructs.add(key);
      }
      break;
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

  for (final func in exports) {
    _line(buf, func.pos.line, func.sourcePath ?? sourcePath);
    buf.writeln('${_functionHeader(func)};');
  }
  if (exports.isNotEmpty) buf.writeln();

  buf.writeln('#endif /* $guard */');
  return buf.toString();
}

