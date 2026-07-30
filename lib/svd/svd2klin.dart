import 'dart:io';

import 'emit.dart';
import 'parse.dart';

class Svd2KlinOptions {
  final String svdPath;
  final Set<String>? peripherals;

  const Svd2KlinOptions({required this.svdPath, this.peripherals});
}

({String header, String klin}) generateFromSvdFile(
  String path, {
  Set<String>? peripherals,
  String includeName = 'stm32f411_regs.h',
}) {
  final device =
      parseSvd(File(path).readAsStringSync(), peripherals: peripherals);
  final guard = includeName.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');
  final output = emitSvd(
    device,
    headerGuard: '${guard}_INCLUDED',
    includeName: includeName,
  );
  return (header: output.header, klin: output.klin);
}
