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

/// call := ident "(" (expr ("," expr)*)? ")"
final class CallStmt extends Stmt {
  final String callee;
  final List<Expr> args;
  final SourcePos pos;

  CallStmt({
    required this.callee,
    required this.args,
    required this.pos,
  });
}

/// if cond block [else (block | if)]
final class IfStmt extends Stmt {
  final Expr cond;
  final Block thenBlock;
  final Stmt? elseBranch; // BlockStmt lub IfStmt
  final SourcePos pos;

  IfStmt({
    required this.cond,
    required this.thenBlock,
    required this.elseBranch,
    required this.pos,
  });
}

/// while cond block
final class WhileStmt extends Stmt {
  final Expr cond;
  final Block body;
  final SourcePos pos;

  WhileStmt({
    required this.cond,
    required this.body,
    required this.pos,
  });
}

/// for name in start..<end block
final class ForRangeStmt extends Stmt {
  final String name;
  final Expr start;
  final Expr endExclusive;
  final Block body;
  final SourcePos pos;

  /// Typ zmiennej pętli — wypełniane przez checker.
  KlinType? resolvedType;

  ForRangeStmt({
    required this.name,
    required this.start,
    required this.endExclusive,
    required this.body,
    required this.pos,
  });
}

/// for [name = init]; [cond]; [post] block
///
/// Init wprowadza mutowalną zmienną `name` (jak `:=` w V).
/// Post to opcjonalne przypisanie `name = expr`.
final class ForCStmt extends Stmt {
  final String? initName;
  final Expr? initExpr;
  final Expr? cond;
  final String? postName;
  final Expr? postExpr;
  final Block body;
  final SourcePos pos;

  /// Typ zmiennej init — wypełniane przez checker.
  KlinType? resolvedInitType;

  ForCStmt({
    required this.initName,
    required this.initExpr,
    required this.cond,
    required this.postName,
    required this.postExpr,
    required this.body,
    required this.pos,
  });
}

/// return [expr]
final class ReturnStmt extends Stmt {
  final Expr? value;
  final SourcePos pos;

  ReturnStmt({required this.value, required this.pos});
}

final class BreakStmt extends Stmt {
  final SourcePos pos;

  BreakStmt(this.pos);
}

final class ContinueStmt extends Stmt {
  final SourcePos pos;

  ContinueStmt(this.pos);
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

final class StringLit extends Expr {
  final String value;
  final SourcePos pos;

  StringLit(this.value, this.pos);
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
