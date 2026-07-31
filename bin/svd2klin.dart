import 'dart:io';

import 'package:klin/svd/svd2klin.dart';

void main(List<String> args) {
  final options = _parseArgs(args);
  if (options == null) {
    stderr.writeln(
      'usage: svd2klin --svd <file.svd> --out-h <file.h> --out-kl <file.kl> '
      '[--peripherals RCC,GPIOA,STK|ALL]',
    );
    exitCode = 2;
    return;
  }
  final result = generateFromSvdFile(
    options.svdPath,
    peripherals: options.peripherals,
    includeName: options.outHeader.split(Platform.pathSeparator).last,
  );
  File(options.outHeader).writeAsStringSync(result.header);
  File(options.outKlin).writeAsStringSync(result.klin);
}

class _Options {
  final String svdPath;
  final String outHeader;
  final String outKlin;
  final Set<String>? peripherals;

  const _Options(this.svdPath, this.outHeader, this.outKlin, this.peripherals);
}

_Options? _parseArgs(List<String> args) {
  String? svd;
  String? outHeader;
  String? outKlin;
  Set<String>? peripherals = {'RCC', 'GPIOA', 'STK'};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    String? value;
    if (arg.startsWith('--peripherals=')) {
      value = arg.substring('--peripherals='.length);
    } else if (arg == '--svd' ||
        arg == '--out-h' ||
        arg == '--out-kl' ||
        arg == '--peripherals') {
      if (++i >= args.length) return null;
      value = args[i];
    } else {
      return null;
    }
    switch (arg.split('=').first) {
      case '--svd':
        svd = value;
      case '--out-h':
        outHeader = value;
      case '--out-kl':
        outKlin = value;
      case '--peripherals':
        peripherals = value == 'ALL'
            ? null
            : value.split(',').map((name) => name.trim()).toSet();
    }
  }
  if (svd == null || outHeader == null || outKlin == null) return null;
  return _Options(svd, outHeader, outKlin, peripherals);
}
