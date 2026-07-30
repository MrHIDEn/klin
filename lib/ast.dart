import 'token.dart';

/// program := "fn" "main" "(" ")" block
final class Program {
  final Block body;
  final SourcePos pos;

  const Program(this.body, this.pos);
}

final class Block {
  final List<Call> calls;
  final SourcePos pos;

  const Block(this.calls, this.pos);
}

/// call := ident "(" string ")"
final class Call {
  final String callee;
  final String argument;
  final SourcePos pos;

  const Call(this.callee, this.argument, this.pos);
}
