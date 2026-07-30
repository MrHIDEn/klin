/// Typy prymitywne Klina i mapowanie na C.
enum PrimKind {
  i8,
  i16,
  i32,
  i64,
  u8,
  u16,
  u32,
  u64,
  f32,
  f64,
  bool_,
  usize,
  isize;

  String get klinName => switch (this) {
        PrimKind.bool_ => 'bool',
        _ => name,
      };

  String get cType => switch (this) {
        PrimKind.i8 => 'int8_t',
        PrimKind.i16 => 'int16_t',
        PrimKind.i32 => 'int32_t',
        PrimKind.i64 => 'int64_t',
        PrimKind.u8 => 'uint8_t',
        PrimKind.u16 => 'uint16_t',
        PrimKind.u32 => 'uint32_t',
        PrimKind.u64 => 'uint64_t',
        PrimKind.f32 => 'float',
        PrimKind.f64 => 'double',
        PrimKind.bool_ => 'bool',
        PrimKind.usize => 'size_t',
        PrimKind.isize => 'ptrdiff_t',
      };

  String get cZero => switch (this) {
        PrimKind.f32 || PrimKind.f64 => '0.0',
        PrimKind.bool_ => 'false',
        _ => '0',
      };

  bool get isInteger => switch (this) {
        PrimKind.i8 ||
        PrimKind.i16 ||
        PrimKind.i32 ||
        PrimKind.i64 ||
        PrimKind.u8 ||
        PrimKind.u16 ||
        PrimKind.u32 ||
        PrimKind.u64 ||
        PrimKind.usize ||
        PrimKind.isize =>
          true,
        _ => false,
      };

  bool get isFloat => this == PrimKind.f32 || this == PrimKind.f64;

  static PrimKind? tryParse(String name) => switch (name) {
        'i8' => PrimKind.i8,
        'i16' => PrimKind.i16,
        'i32' => PrimKind.i32,
        'i64' => PrimKind.i64,
        'u8' => PrimKind.u8,
        'u16' => PrimKind.u16,
        'u32' => PrimKind.u32,
        'u64' => PrimKind.u64,
        'f32' => PrimKind.f32,
        'f64' => PrimKind.f64,
        'bool' => PrimKind.bool_,
        'usize' => PrimKind.usize,
        'isize' => PrimKind.isize,
        _ => null,
      };
}

sealed class KlinType {
  const KlinType();

  String get displayName;
}

final class PrimType extends KlinType {
  final PrimKind kind;

  const PrimType(this.kind);

  @override
  String get displayName => kind.klinName;

  @override
  bool operator ==(Object other) => other is PrimType && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

final class VoidType extends KlinType {
  const VoidType();

  @override
  String get displayName => 'void';

  @override
  bool operator ==(Object other) => other is VoidType;

  @override
  int get hashCode => 0;
}

final class StructType extends KlinType {
  final String moduleName;
  final String name;

  const StructType(this.moduleName, this.name);

  @override
  String get displayName => moduleName.isEmpty ? name : '$moduleName.$name';

  @override
  bool operator ==(Object other) =>
      other is StructType &&
      other.moduleName == moduleName &&
      other.name == name;

  @override
  int get hashCode => Object.hash(moduleName, name);
}

final class PtrType extends KlinType {
  final KlinType pointee;
  final bool isMut;
  final bool isVolatile;

  const PtrType(this.pointee, {this.isMut = false, this.isVolatile = false});

  @override
  String get displayName =>
      '*${isMut ? 'mut ' : ''}${isVolatile ? 'volatile ' : ''}${pointee.displayName}';

  @override
  bool operator ==(Object other) =>
      other is PtrType &&
      other.pointee == pointee &&
      other.isMut == isMut &&
      other.isVolatile == isVolatile;

  @override
  int get hashCode => Object.hash(pointee, isMut, isVolatile);
}

final class ArrayType extends KlinType {
  final KlinType elem;
  final int len;

  const ArrayType(this.elem, this.len);

  @override
  String get displayName => '[$len]${elem.displayName}';

  @override
  bool operator ==(Object other) =>
      other is ArrayType && other.elem == elem && other.len == len;

  @override
  int get hashCode => Object.hash(elem, len);
}

final class SliceType extends KlinType {
  final PrimType elem;

  const SliceType(this.elem);

  @override
  String get displayName => '[]${elem.displayName}';

  @override
  bool operator ==(Object other) => other is SliceType && other.elem == elem;

  @override
  int get hashCode => elem.hashCode;
}

/// Literał całkowity bez przypisanego jeszcze typu konkretnego.
final class UntypedInt extends KlinType {
  const UntypedInt();

  @override
  String get displayName => 'untyped int';

  @override
  bool operator ==(Object other) => other is UntypedInt;

  @override
  int get hashCode => 1;
}

/// Literał zmiennoprzecinkowy bez przypisanego jeszcze typu konkretnego.
final class UntypedFloat extends KlinType {
  const UntypedFloat();

  @override
  String get displayName => 'untyped float';

  @override
  bool operator ==(Object other) => other is UntypedFloat;

  @override
  int get hashCode => 2;
}

/// Literał napisu C (tylko jako argument FFI — bez pełnego typu `str` w języku).
final class StrType extends KlinType {
  const StrType();

  @override
  String get displayName => 'string';

  @override
  bool operator ==(Object other) => other is StrType;

  @override
  int get hashCode => 3;
}
