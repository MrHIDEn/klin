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
  final List<SvdField> fields;

  SvdRegister(this.name, this.addressOffset, this.fields);
}

class SvdField {
  final String name;
  final int bitOffset;
  final int bitWidth;
  List<SvdEnumValue> enums;

  SvdField(this.name, this.bitOffset, this.bitWidth, this.enums);
}

class SvdEnumValue {
  final String name;
  final int value;

  SvdEnumValue(this.name, this.value);
}
