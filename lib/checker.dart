import 'ast.dart';
import 'token.dart';
import 'type.dart';

final class CheckError implements Exception {
  final String message;
  final SourcePos pos;

  const CheckError(this.message, this.pos);

  @override
  String toString() => '${pos.line}:${pos.col}: $message';
}

final class _Symbol {
  final String name;
  final KlinType type;
  final bool isMut;
  final SourcePos pos;

  const _Symbol({
    required this.name,
    required this.type,
    required this.isMut,
    required this.pos,
  });
}

final class _Scope {
  final _Scope? parent;
  final Map<String, _Symbol> _symbols = {};

  _Scope(this.parent);

  void define(_Symbol symbol) {
    if (_symbols.containsKey(symbol.name)) {
      throw CheckError(
        'ponowna deklaracja `${symbol.name}` w tym samym zakresie',
        symbol.pos,
      );
    }
    _symbols[symbol.name] = symbol;
  }

  _Symbol? lookup(String name) {
    final local = _symbols[name];
    if (local != null) return local;
    return parent?.lookup(name);
  }
}

/// Tablica symboli + sprawdzanie typów. Mutuje `resolvedType` na węzłach AST.
final class Checker {
  _Scope _scope = _Scope(null);

  void check(Program program) {
    _scope = _Scope(null);
    _checkBlock(program.body);
  }

  void _checkBlock(Block block) {
    _scope = _Scope(_scope);
    for (final stmt in block.stmts) {
      _checkStmt(stmt);
    }
    _scope = _scope.parent!;
  }

  void _checkStmt(Stmt stmt) {
    switch (stmt) {
      case LetStmt(:final isMut, :final name, :final typeName, :final init, :final pos):
        KlinType? annotated;
        if (typeName != null) {
          final kind = PrimKind.tryParse(typeName);
          if (kind == null) {
            throw CheckError('nieznany typ `$typeName`', pos);
          }
          annotated = PrimType(kind);
        }

        final KlinType resolved;
        if (init != null) {
          final initType = _inferExpr(init);
          if (annotated != null) {
            _expectAssignable(annotated, initType, init.pos);
            resolved = annotated;
            _materialize(init, resolved);
          } else {
            resolved = _defaultConcrete(initType, init.pos);
            _materialize(init, resolved);
          }
        } else if (annotated != null) {
          // ZII — brak inicjalizatora, typ z adnotacji.
          resolved = annotated;
        } else {
          throw CheckError(
            'zmienna `$name` wymaga typu lub inicjalizatora',
            pos,
          );
        }

        stmt.resolvedType = resolved;
        _scope.define(
          _Symbol(name: name, type: resolved, isMut: isMut, pos: pos),
        );

      case AssignStmt(:final name, :final value, :final pos):
        final sym = _scope.lookup(name);
        if (sym == null) {
          throw CheckError('nieznana zmienna `$name`', pos);
        }
        if (!sym.isMut) {
          throw CheckError(
            'nie można przypisać do niemutowalnej zmiennej `$name`',
            pos,
          );
        }
        final valueType = _inferExpr(value);
        _expectAssignable(sym.type, valueType, value.pos);
        _materialize(value, sym.type);

      case CallStmt():
        // 001: puts(string) — bez sprawdzania sygnatur w tym kroku.
        break;

      case BlockStmt(:final block):
        _checkBlock(block);
    }
  }

  /// Wnioskowanie bez kontekstu — może zwrócić typ untyped.
  KlinType _inferExpr(Expr expr) {
    final type = switch (expr) {
      IntLit() => const UntypedInt(),
      FloatLit() => const UntypedFloat(),
      BoolLit() => const PrimType(PrimKind.bool_),
      NameExpr(:final name, :final pos) => () {
          final sym = _scope.lookup(name);
          if (sym == null) {
            throw CheckError('nieznana zmienna `$name`', pos);
          }
          return sym.type;
        }(),
      UnaryExpr(:final op, :final operand, :final pos) => () {
          final t = _inferExpr(operand);
          if (op != '-') {
            throw CheckError('nieznany operator unarny `$op`', pos);
          }
          final concrete = _defaultConcrete(t, operand.pos);
          if (concrete is! PrimType ||
              !(concrete.kind.isInteger || concrete.kind.isFloat)) {
            throw CheckError(
              'operator `-` wymaga typu liczbowego, dostano `${concrete.displayName}`',
              pos,
            );
          }
          if (_isUnsigned(concrete.kind)) {
            throw CheckError(
              'operator `-` nie jest dozwolony dla typu bez znaku `${concrete.displayName}`',
              pos,
            );
          }
          _materialize(operand, concrete);
          return concrete;
        }(),
      BinaryExpr(:final left, :final op, :final right, :final pos) =>
        _inferBinary(left, op, right, pos),
      GroupExpr(:final inner) => _inferExpr(inner),
    };
    if (type is PrimType) expr.resolvedType = type;
    return type;
  }

  KlinType _inferBinary(Expr left, String op, Expr right, SourcePos pos) {
    final lt = _inferExpr(left);
    final rt = _inferExpr(right);

    final KlinType unified;
    if (lt is UntypedInt && rt is UntypedInt) {
      unified = const UntypedInt();
    } else if (lt is UntypedFloat && rt is UntypedFloat) {
      unified = const UntypedFloat();
    } else if (lt is UntypedInt && rt is UntypedFloat) {
      unified = const UntypedFloat();
    } else if (lt is UntypedFloat && rt is UntypedInt) {
      unified = const UntypedFloat();
    } else if (lt is UntypedInt && rt is PrimType && rt.kind.isInteger) {
      unified = rt;
    } else if (rt is UntypedInt && lt is PrimType && lt.kind.isInteger) {
      unified = lt;
    } else if (lt is UntypedFloat && rt is PrimType && rt.kind.isFloat) {
      unified = rt;
    } else if (rt is UntypedFloat && lt is PrimType && lt.kind.isFloat) {
      unified = lt;
    } else if (lt is UntypedInt && rt is PrimType && rt.kind.isFloat) {
      unified = rt;
    } else if (rt is UntypedInt && lt is PrimType && lt.kind.isFloat) {
      unified = lt;
    } else if (lt == rt) {
      unified = lt;
    } else {
      throw CheckError(
        'niezgodność typów: `${lt.displayName}` $op `${rt.displayName}`',
        pos,
      );
    }

    final concrete = unified is UntypedInt || unified is UntypedFloat
        ? _defaultConcrete(unified, pos)
        : unified;

    if (concrete is! PrimType ||
        !(concrete.kind.isInteger || concrete.kind.isFloat)) {
      throw CheckError(
        'operator `$op` wymaga typów liczbowych, dostano `${concrete.displayName}`',
        pos,
      );
    }

    _materialize(left, concrete);
    _materialize(right, concrete);
    return concrete;
  }

  /// Ustawia konkretny typ na wyrażeniu (i rekurencyjnie na poddrzewie
  /// tam, gdzie były literały untyped).
  void _materialize(Expr expr, KlinType type) {
    expr.resolvedType = type;
    switch (expr) {
      case UnaryExpr(:final operand):
        _materialize(operand, type);
      case BinaryExpr(:final left, :final right):
        _materialize(left, type);
        _materialize(right, type);
      case GroupExpr(:final inner):
        _materialize(inner, type);
      case IntLit() || FloatLit() || BoolLit() || NameExpr():
        break;
    }
  }

  void _expectAssignable(KlinType target, KlinType source, SourcePos pos) {
    if (!_isAssignable(target, source)) {
      throw CheckError(
        'niezgodność typów: oczekiwano `${target.displayName}`, '
        'dostano `${source.displayName}`',
        pos,
      );
    }
  }

  bool _isAssignable(KlinType target, KlinType source) {
    if (target == source) return true;
    if (source is UntypedInt && target is PrimType && target.kind.isInteger) {
      return true;
    }
    if (source is UntypedFloat && target is PrimType && target.kind.isFloat) {
      return true;
    }
    if (source is UntypedInt && target is PrimType && target.kind.isFloat) {
      return true;
    }
    return false;
  }

  KlinType _defaultConcrete(KlinType type, SourcePos pos) {
    return switch (type) {
      UntypedInt() => const PrimType(PrimKind.i32),
      UntypedFloat() => const PrimType(PrimKind.f64),
      PrimType() => type,
    };
  }

  static bool _isUnsigned(PrimKind kind) => switch (kind) {
        PrimKind.u8 ||
        PrimKind.u16 ||
        PrimKind.u32 ||
        PrimKind.u64 ||
        PrimKind.usize =>
          true,
        _ => false,
      };
}
