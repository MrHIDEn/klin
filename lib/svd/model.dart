class SvdDevice {
  final List<SvdPeripheral> peripherals;

  SvdDevice(this.peripherals);
}

class SvdPeripheral {
  final String name;
  final int baseAddress;
  final List<SvdRegister> registers;

  SvdPeripheral(this.name, this.baseAddress, this.registers);
}

class SvdRegister {
  final String name;
  final int addressOffset;
  List<SvdField> fields;
  final String? access;

  SvdRegister(this.name, this.addressOffset, this.fields, {this.access});

  bool get isWriteOnly => access == 'write-only';
  bool get isReadOnly => access == 'read-only';
}

class SvdField {
  final String name;
  final int bitOffset;
  final int bitWidth;
  List<SvdEnumValue> enums;
  final String? access;

  SvdField(this.name, this.bitOffset, this.bitWidth, this.enums, {this.access});

  bool get isWriteOnly => access == 'write-only';
  bool get isReadOnly => access == 'read-only';
}

class SvdEnumValue {
  final String name;
  final int value;

  SvdEnumValue(this.name, this.value);
}
