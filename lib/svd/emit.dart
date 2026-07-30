import 'model.dart';

class SvdEmitResult {
  final String header;
  final String klin;

  const SvdEmitResult(this.header, this.klin);
}

SvdEmitResult emitSvd(
  SvdDevice device, {
  required String headerGuard,
  required String includeName,
}) {
  final header = StringBuffer()
    ..writeln('#pragma once')
    ..writeln('#ifndef $headerGuard')
    ..writeln('#define $headerGuard')
    ..writeln('#include <stdint.h>')
    ..writeln();
  final klin = StringBuffer();
  var firstImport = true;

  for (final peripheral in device.peripherals) {
    for (final register in peripheral.registers) {
      for (final field in register.fields) {
        final prefix = '${peripheral.name}_${register.name}_${field.name}';
        final address = _hex(peripheral.baseAddress + register.addressOffset);
        final mask = _mask(field.bitWidth, field.bitOffset);
        header
          ..writeln('static inline void ${prefix}_write(uint32_t v) {')
          ..writeln('  volatile uint32_t *r = (volatile uint32_t *)($address);')
          ..writeln('  uint32_t m = $mask;')
          ..writeln('  *r = (*r & ~m) | ((v << ${field.bitOffset}) & m);')
          ..writeln('}')
          ..writeln('static inline void ${prefix}_set(uint32_t v) {')
          ..writeln('  ${prefix}_write(v);')
          ..writeln('}');
        if (field.bitWidth == 1) {
          header
            ..writeln('static inline void ${prefix}_toggle(void) {')
            ..writeln('  *(volatile uint32_t *)($address) ^= '
                '(1u << ${field.bitOffset});')
            ..writeln('}');
        }
        for (final value in field.enums) {
          header.writeln('#define ${prefix}_${value.name} ${value.value}u');
        }
        header.writeln();

        if (firstImport) {
          klin.writeln('@[cinclude("$includeName")]');
          firstImport = false;
        }
        klin
          ..writeln('@[cimport, codename("${prefix}_write")]')
          ..writeln('pub fn ${prefix}_write(v: u32)')
          ..writeln('@[cimport, codename("${prefix}_set")]')
          ..writeln('pub fn ${prefix}_set(v: u32)');
        if (field.bitWidth == 1) {
          klin
            ..writeln('@[cimport, codename("${prefix}_toggle")]')
            ..writeln('pub fn ${prefix}_toggle()');
        }
        if (field.enums.isNotEmpty) {
          klin.writeln('// Enum values (use integer literals in Klin):');
          for (final value in field.enums) {
            klin.writeln('// ${prefix}_${value.name} = ${value.value}');
          }
        }
        klin.writeln();
      }
    }
  }
  header.writeln('#endif /* $headerGuard */');
  return SvdEmitResult(header.toString(), klin.toString());
}

String _hex(int value) => '0x${value.toRadixString(16).toUpperCase()}u';

String _mask(int width, int bitOffset) {
  final bits = width == 32 ? '0xFFFFFFFFu' : '${(1 << width) - 1}u';
  return bitOffset == 0 ? bits : '($bits << $bitOffset)';
}
