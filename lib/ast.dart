import 'token.dart';
import 'type.dart';

/// program := (struct | func)+
final class Program {
  final List<StructDecl> structs;
  final List<FuncDecl> funcs;
  final SourcePos pos;
  final Map<String, Set<String>> imports;

  const Program(this.structs, this.funcs, this.pos, {this.imports = const {}});
}

/// Jedna jednostka źródłowa przed połączeniem jej przez loader projektu.
final class ModuleUnit {
  final String? declaredName;
  final List<String> imports;
  final List<StructDecl> structs;
  final List<FuncDecl> funcs;
  final SourcePos pos;

  const ModuleUnit({
    required this.declaredName,
    required this.imports,
    required this.structs,
    required this.funcs,
    required this.pos,
  });
}

final class StructDecl {
  final String name;
  final List<FieldDecl> fields;
  final SourcePos pos;
  bool isPub;
  String moduleName;
  String? sourcePath;

  StructDecl({
    required this.name,
    required this.fields,
    required this.pos,
    this.isPub = false,
    this.moduleName = '',
    this.sourcePath,
  });
}

/// name: primitive-type
final class FieldDecl {
  final String name;
  final String typeName;
  final SourcePos pos;

  /// Wypełniane przez checker.
  KlinType? resolvedType;

  FieldDecl({
    required this.name,
    required this.typeName,
    required this.pos,
  });
}

/// fn [(mut)? name: Type] name(params): returnType? block
final class FuncDecl {
  final String name;
  final Receiver? receiver;
  final List<Param> params;
  final String? returnTypeName;
  final Block body;
  final SourcePos pos;
  bool isPub;
  String moduleName;
  String? sourcePath;

  /// Wypełniane przez checker.
  KlinType? resolvedReturnType;

  FuncDecl({
    required this.name,
    required this.receiver,
    required this.params,
    required this.returnTypeName,
    required this.body,
    required this.pos,
    this.isPub = false,
    this.moduleName = '',
    this.sourcePath,
  });
}

final class Receiver {
  final String name;
  final String typeName;
  final bool isMut;
  final SourcePos pos;

  /// Wypełniane przez checker.
  KlinType? resolvedType;

  Receiver({
    required this.name,
    required this.typeName,
    required this.isMut,
    required this.pos,
  });
}

/// name: type
final class Param {
  final String name;
  final String typeName;
  final SourcePos pos;

  /// Wypełniane przez checker.
  KlinType? resolvedType;

  Param({
    required this.name,
    required this.typeName,
    required this.pos,
  });
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

/// target = expr, gdzie target to NameExpr lub FieldExpr.
final class AssignStmt extends Stmt {
  final Expr target;
  final Expr value;
  final SourcePos pos;

  AssignStmt({
    required this.target,
    required this.value,
    required this.pos,
  });
}

/// call := ident "(" (expr ("," expr)*)? ")"
final class CallStmt extends Stmt {
  final String? moduleName;
  final String callee;
  final List<Expr> args;
  final SourcePos pos;
  String? resolvedCallee;

  CallStmt({
    this.moduleName,
    required this.callee,
    required this.args,
    required this.pos,
  });
}

final class MethodCallStmt extends Stmt {
  final MethodCallExpr call;

  MethodCallStmt(this.call);

  @override
  SourcePos get pos => call.pos;
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

  /// Wypełniane przez checker: mut receiver emitowany jako wskaźnik (`->`).
  bool isPtrReceiver = false;

  NameExpr(this.name, this.pos);
}

final class FieldExpr extends Expr {
  final Expr object;
  final String name;
  final SourcePos pos;

  FieldExpr({
    required this.object,
    required this.name,
    required this.pos,
  });
}

final class MethodCallExpr extends Expr {
  final Expr receiver;
  final String name;
  final List<Expr> args;
  final SourcePos pos;

  /// Wypełniane przez checker.
  String? mangledName;
  bool receiverByRef = false;

  MethodCallExpr({
    required this.receiver,
    required this.name,
    required this.args,
    required this.pos,
  });
}

final class StructLitExpr extends Expr {
  final String? moduleName;
  final String typeName;
  final Map<String, Expr>? namedFields;
  final List<Expr>? positionalFields;
  final SourcePos pos;

  StructLitExpr.named({
    this.moduleName,
    required this.typeName,
    required Map<String, Expr> fields,
    required this.pos,
  })  : namedFields = fields,
        positionalFields = null;

  StructLitExpr.positional({
    this.moduleName,
    required this.typeName,
    required List<Expr> fields,
    required this.pos,
  })  : namedFields = null,
        positionalFields = fields;
}

/// call := ident "(" (expr ("," expr)*)? ")"
final class CallExpr extends Expr {
  final String? moduleName;
  final String callee;
  final List<Expr> args;
  final SourcePos pos;
  String? resolvedCallee;

  CallExpr({
    this.moduleName,
    required this.callee,
    required this.args,
    required this.pos,
  });
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
