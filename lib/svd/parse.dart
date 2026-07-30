import 'package:xml/xml.dart';

import 'model.dart';

/// Reads the register subset needed by the SVD-to-C/Klin generator.
SvdDevice parseSvd(String source, {Set<String>? peripherals}) {
  final document = XmlDocument.parse(source);
  final pendingEnums = <SvdField, String>{};
  final enumGroups = <SvdField, String>{};
  final pendingRegisterDerived = <SvdRegister, String>{};
  final parsed = <SvdPeripheral>[];

  for (final element in document.findAllElements('peripheral')) {
    final name = _childText(element, 'name');
    if (name == null || (peripherals != null && !peripherals.contains(name))) {
      continue;
    }
    final baseAddress = _number(_childText(element, 'baseAddress')!);
    final registers = <SvdRegister>[];
    final registersElement = element.getElement('registers');
    if (registersElement != null) {
      for (final registerElement in registersElement.findElements('register')) {
        registers.addAll(
          _parseRegisters(
            registerElement,
            pendingEnums,
            enumGroups,
            pendingRegisterDerived,
          ),
        );
      }
    }
    parsed.add(SvdPeripheral(name, baseAddress, registers));
  }

  _resolveRegisterDerived(parsed, pendingRegisterDerived);
  _resolveEnums(parsed, pendingEnums, enumGroups);
  if (peripherals == null || peripherals.contains('STK')) {
    parsed.add(_sysTick());
  }
  return SvdDevice(parsed);
}

List<SvdRegister> _parseRegisters(
  XmlElement element,
  Map<SvdField, String> pendingEnums,
  Map<SvdField, String> enumGroups,
  Map<SvdRegister, String> pendingRegisterDerived,
) {
  final name = _childText(element, 'name')!;
  final offset = _number(_childText(element, 'addressOffset')!);
  final access = _childText(element, 'access');
  final dim = _optionalNumber(element, 'dim') ?? 1;
  final increment = _optionalNumber(element, 'dimIncrement') ?? 0;
  final indices = _dimIndices(element, dim);
  final derived = element.getAttribute('derivedFrom');
  final out = <SvdRegister>[];
  for (var i = 0; i < dim; i++) {
    final fieldsElement = element.getElement('fields');
    final fields = <SvdField>[];
    if (fieldsElement != null) {
      for (final fieldElement in fieldsElement.findElements('field')) {
        fields.addAll(_parseFields(fieldElement, pendingEnums, enumGroups));
      }
    }
    final register = SvdRegister(
      _expandName(name, indices[i]),
      offset + i * increment,
      fields,
      access: access,
    );
    if (derived != null) {
      pendingRegisterDerived[register] = derived.replaceAll('%s', indices[i]);
    }
    out.add(register);
  }
  return out;
}

List<SvdField> _parseFields(
  XmlElement element,
  Map<SvdField, String> pendingEnums,
  Map<SvdField, String> enumGroups,
) {
  final name = _childText(element, 'name')!;
  final offset = _number(_childText(element, 'bitOffset')!);
  final width = _number(_childText(element, 'bitWidth')!);
  final access = _childText(element, 'access');
  final dim = _optionalNumber(element, 'dim') ?? 1;
  final increment = _optionalNumber(element, 'dimIncrement') ?? 0;
  final indices = _dimIndices(element, dim);
  final enumsElement = element.getElement('enumeratedValues');
  final enumGroup =
      enumsElement == null ? null : _childText(enumsElement, 'name');
  final enums = <SvdEnumValue>[
    if (enumsElement != null)
      for (final value in enumsElement.findElements('enumeratedValue'))
        if (_childText(value, 'name') case final valueName?)
          if (_childText(value, 'value') case final rawValue?)
            SvdEnumValue(valueName, _number(rawValue)),
  ];

  final out = <SvdField>[];
  for (var i = 0; i < dim; i++) {
    final field = SvdField(
      _expandName(name, indices[i]),
      offset + i * increment,
      width,
      List.of(enums),
      access: access,
    );
    final derived = enumsElement?.getAttribute('derivedFrom') ??
        element.getAttribute('derivedFrom');
    if (derived != null) pendingEnums[field] = derived;
    if (enumGroup != null) enumGroups[field] = enumGroup;
    out.add(field);
  }
  return out;
}

void _resolveRegisterDerived(
  List<SvdPeripheral> peripherals,
  Map<SvdRegister, String> pending,
) {
  final byPath = <String, SvdRegister>{};
  for (final peripheral in peripherals) {
    for (final register in peripheral.registers) {
      byPath['${peripheral.name}.${register.name}'] = register;
    }
  }
  for (final entry in pending.entries) {
    final target = byPath[entry.value];
    if (target == null) continue;
    entry.key.fields = [
      for (final field in target.fields)
        SvdField(
          field.name,
          field.bitOffset,
          field.bitWidth,
          List.of(field.enums),
          access: field.access ?? target.access,
        ),
    ];
  }
}

void _resolveEnums(
  List<SvdPeripheral> peripherals,
  Map<SvdField, String> pendingEnums,
  Map<SvdField, String> enumGroups,
) {
  final byPath = <String, SvdField>{};
  final byEnumGroup = <String, SvdField>{};
  for (final peripheral in peripherals) {
    for (final register in peripheral.registers) {
      for (final field in register.fields) {
        final path = '${peripheral.name}.${register.name}.${field.name}';
        byPath[path] = field;
        final owner = '${peripheral.name}.${register.name}';
        byEnumGroup['$owner.${enumGroups[field] ?? field.name}'] = field;
      }
    }
  }
  for (final entry in pendingEnums.entries) {
    final field = entry.key;
    final reference = entry.value.replaceAll('%s', _suffix(field.name));
    final owner = _ownerPath(byPath, field);
    final target = reference.contains('.')
        ? byPath[reference] ?? byEnumGroup[reference]
        : owner == null
            ? null
            : _fieldInRegister(byPath, owner, reference) ??
                byEnumGroup['$owner.$reference'];
    if (target != null) field.enums = List.of(target.enums);
  }
}

String? _ownerPath(Map<String, SvdField> paths, SvdField field) {
  for (final entry in paths.entries) {
    if (identical(entry.value, field)) {
      return entry.key.substring(0, entry.key.lastIndexOf('.'));
    }
  }
  return null;
}

SvdField? _fieldInRegister(
  Map<String, SvdField> paths,
  String owner,
  String name,
) =>
    paths['$owner.$name'];

List<String> _dimIndices(XmlElement element, int dim) {
  final raw = _childText(element, 'dimIndex');
  if (raw == null) return List.generate(dim, (i) => i.toString());
  final values = <String>[];
  for (final part in raw.split(',')) {
    final range = part.trim().split('-');
    if (range.length == 2 &&
        int.tryParse(range[0]) != null &&
        int.tryParse(range[1]) != null) {
      final start = int.parse(range[0]);
      final end = int.parse(range[1]);
      values.addAll(
        List.generate(end - start + 1, (i) => (start + i).toString()),
      );
    } else {
      values.add(part.trim());
    }
  }
  return values.length == dim
      ? values
      : List.generate(dim, (i) => i.toString());
}

String _expandName(String name, String index) =>
    name.replaceAll('%s', index).replaceAll('[%s]', index);

String _suffix(String name) {
  final match = RegExp(r'(\d+)$').firstMatch(name);
  return match?.group(1) ?? '';
}

String? _childText(XmlElement element, String name) =>
    element.getElement(name)?.innerText.trim();

int? _optionalNumber(XmlElement element, String name) {
  final text = _childText(element, name);
  return text == null ? null : _number(text);
}

int _number(String value) {
  final normalized = value.trim().replaceAll('_', '');
  return normalized.startsWith('0x') || normalized.startsWith('0X')
      ? int.parse(normalized.substring(2), radix: 16)
      : int.parse(normalized);
}

// STM32F411's vendor SVD omits the core SysTick peripheral. Keep this small
// explicit model so a filtered STM32 blink build still has its timer registers.
SvdPeripheral _sysTick() => SvdPeripheral('STK', 0xE000E010, [
      SvdRegister('CSR', 0, [
        SvdField('ENABLE', 0, 1, []),
        SvdField('TICKINT', 1, 1, []),
        SvdField('CLKSOURCE', 2, 1, []),
      ], access: 'read-write'),
      SvdRegister('RVR', 4, [SvdField('RELOAD', 0, 24, [])],
          access: 'read-write'),
      SvdRegister('CVR', 8, [SvdField('CURRENT', 0, 24, [])],
          access: 'read-write'),
    ]);
