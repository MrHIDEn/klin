import 'token.dart';
import 'type.dart';

/// program := "fn" "main" "(" ")" block
final class Program {
  final Block body;
  final SourcePos pos;

  const Program(this.body, this.pos);
}

final class Block {
  final List<Stmt> stmts;
  final SourcePos pos;

  const Block(this.stmts, this.pos);
}

sealed class Stmt {
  SourcePos get pos;
}

/// let [mut] name [: type] [= expr]
final class LetStmt extends Stmt {
  final bool isMut;
  final String name;
  final String? typeName;
  final Expr? init;
  final SourcePos pos;

  /// Wypełniane przez checker.
  KlinType? resolvedType;

  LetStmt({
    required this.isMut,
    required this.name,
    required this.typeName,
    required this.init,
    required this.pos,
  });
}

/// name = expr
final class AssignStmt extends Stmt {
  final String name;
  final Expr value;
  final SourcePos pos;

  AssignStmt({
    required this.name,
    required this.value,
    required this.pos,
  });
}

/// call := ident "(" string ")"  (jak w 001)
final class CallStmt extends Stmt {
  final String callee;
  final String argument;
  final SourcePos pos;

  CallStmt({
    required this.callee,
    required this.argument,
    required this.pos,
  });
}

/// Zagnieżdżony blok — osobny zakres.
final class BlockStmt extends Stmt {
  final Block block;

  BlockStmt(this.block);

  @override
  SourcePos get pos => block.pos;
}

sealed class Expr {
  SourcePos get pos;

  /// Wypełniane przez checker.
  KlinType? resolvedType;
}

final class IntLit extends Expr {
  final String lexeme;
  final SourcePos pos;

  IntLit(this.lexeme, this.pos);
}

final class FloatLit extends Expr {
  final String lexeme;
  final SourcePos pos;

  FloatLit(this.lexeme, this.pos);
}

final class BoolLit extends Expr {
  final bool value;
  final SourcePos pos;

  BoolLit(this.value, this.pos);
}

final class NameExpr extends Expr {
  final String name;
  final SourcePos pos;

  NameExpr(this.name, this.pos);
}

final class UnaryExpr extends Expr {
  final String op;
  final Expr operand;
  final SourcePos pos;

  UnaryExpr(this.op, this.operand, this.pos);
}

final class BinaryExpr extends Expr {
  final Expr left;
  final String op;
  final Expr right;
  final SourcePos pos;

  BinaryExpr(this.left, this.op, this.right, this.pos);
}

final class GroupExpr extends Expr {
  final Expr inner;
  final SourcePos pos;

  GroupExpr(this.inner, this.pos);
}
