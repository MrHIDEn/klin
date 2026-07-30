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
  int _loopDepth = 0;

  void check(Program program) {
    _scope = _Scope(null);
    _loopDepth = 0;
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

      case CallStmt(:final args):
        // 001/003: FFI do C (puts/printf) — bez sprawdzania sygnatur.
        for (final arg in args) {
          _inferExpr(arg);
        }

      case IfStmt(:final cond, :final thenBlock, :final elseBranch):
        _expectBoolCond(cond);
        _checkBlock(thenBlock);
        if (elseBranch != null) _checkStmt(elseBranch);

      case WhileStmt(:final cond, :final body):
        _expectBoolCond(cond);
        _loopDepth++;
        _checkBlock(body);
        _loopDepth--;

      case ForRangeStmt(
          :final name,
          :final start,
          :final endExclusive,
          :final body,
          :final pos
        ):
        final startTy = _inferExpr(start);
        final endTy = _inferExpr(endExclusive);
        final unified = _unifyNumeric(startTy, endTy, pos);
        final concrete = _defaultConcrete(unified, pos);
        if (concrete is! PrimType || !concrete.kind.isInteger) {
          throw CheckError(
            'zakres `for` wymaga typów całkowitych, dostano `${concrete.displayName}`',
            pos,
          );
        }
        _materialize(start, concrete);
        _materialize(endExclusive, concrete);
        stmt.resolvedType = concrete;

        _scope = _Scope(_scope);
        _scope.define(
          _Symbol(name: name, type: concrete, isMut: true, pos: pos),
        );
        _loopDepth++;
        _checkBlock(body);
        _loopDepth--;
        _scope = _scope.parent!;

      case ForCStmt(
          :final initName,
          :final initExpr,
          :final cond,
          :final postName,
          :final postExpr,
          :final body,
          :final pos
        ):
        _scope = _Scope(_scope);
        if (initName != null && initExpr != null) {
          final initTy = _inferExpr(initExpr);
          final concrete = _defaultConcrete(initTy, initExpr.pos);
          _materialize(initExpr, concrete);
          stmt.resolvedInitType = concrete;
          _scope.define(
            _Symbol(name: initName, type: concrete, isMut: true, pos: pos),
          );
        }
        if (cond != null) _expectBoolCond(cond);
        if (postName != null && postExpr != null) {
          final sym = _scope.lookup(postName);
          if (sym == null) {
            throw CheckError('nieznana zmienna `$postName`', postExpr.pos);
          }
          if (!sym.isMut) {
            throw CheckError(
              'nie można przypisać do niemutowalnej zmiennej `$postName`',
              postExpr.pos,
            );
          }
          final postTy = _inferExpr(postExpr);
          _expectAssignable(sym.type, postTy, postExpr.pos);
          _materialize(postExpr, sym.type);
        }
        _loopDepth++;
        _checkBlock(body);
        _loopDepth--;
        _scope = _scope.parent!;

      case ReturnStmt(:final value):
        if (value != null) {
          final t = _inferExpr(value);
          final concrete = _defaultConcrete(t, value.pos);
          if (concrete is! PrimType || !concrete.kind.isInteger) {
            throw CheckError(
              '`return` w main wymaga typu całkowitego, dostano `${concrete.displayName}`',
              value.pos,
            );
          }
          _materialize(value, concrete);
        }

      case BreakStmt(:final pos):
        if (_loopDepth == 0) {
          throw CheckError('`break` poza pętlą', pos);
        }

      case ContinueStmt(:final pos):
        if (_loopDepth == 0) {
          throw CheckError('`continue` poza pętlą', pos);
        }

      case BlockStmt(:final block):
        _checkBlock(block);
    }
  }

  void _expectBoolCond(Expr cond) {
    final t = _inferExpr(cond);
    // Porównania już dają bool. Literał bool OK. Untyped/liczby — nie.
    if (t is PrimType && t.kind == PrimKind.bool_) {
      return;
    }
    throw CheckError(
      'warunek wymaga typu `bool`, dostano `${t.displayName}`',
      cond.pos,
    );
  }

  /// Wnioskowanie bez kontekstu — może zwrócić typ untyped.
  KlinType _inferExpr(Expr expr) {
    final type = switch (expr) {
      IntLit() => const UntypedInt(),
      FloatLit() => const UntypedFloat(),
      BoolLit() => const PrimType(PrimKind.bool_),
      StringLit() => const StrType(),
      NameExpr(:final name, :final pos) => () {
          final sym = _scope.lookup(name);
          if (sym == null) {
            throw CheckError('nieznana zmienna `$name`', pos);
          }
          return sym.type;
        }(),
      UnaryExpr(:final op, :final operand, :final pos) => () {
          if (op == '!') {
            final t = _inferExpr(operand);
            if (t is! PrimType || t.kind != PrimKind.bool_) {
              throw CheckError(
                'operator `!` wymaga typu `bool`, dostano `${t.displayName}`',
                pos,
              );
            }
            return const PrimType(PrimKind.bool_);
          }
          if (op != '-') {
            throw CheckError('nieznany operator unarny `$op`', pos);
          }
          final t = _inferExpr(operand);
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
    if (type is PrimType || type is StrType) expr.resolvedType = type;
    return type;
  }

  static const _cmpOps = {'==', '!=', '<', '<=', '>', '>='};
  static const _arithOps = {'+', '-', '*', '/', '%'};

  KlinType _inferBinary(Expr left, String op, Expr right, SourcePos pos) {
    if (_cmpOps.contains(op)) {
      return _inferComparison(left, op, right, pos);
    }
    if (!_arithOps.contains(op)) {
      throw CheckError('nieznany operator `$op`', pos);
    }

    final lt = _inferExpr(left);
    final rt = _inferExpr(right);
    final unified = _unifyNumeric(lt, rt, pos);
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

    if (op == '%' && !concrete.kind.isInteger) {
      throw CheckError(
        'operator `%` wymaga typów całkowitych, dostano `${concrete.displayName}`',
        pos,
      );
    }

    _materialize(left, concrete);
    _materialize(right, concrete);
    return concrete;
  }

  KlinType _inferComparison(Expr left, String op, Expr right, SourcePos pos) {
    final lt = _inferExpr(left);
    final rt = _inferExpr(right);

    // bool == bool / !=
    if (lt is PrimType &&
        lt.kind == PrimKind.bool_ &&
        rt is PrimType &&
        rt.kind == PrimKind.bool_) {
      if (op != '==' && op != '!=') {
        throw CheckError(
          'operator `$op` nie jest dozwolony dla typu `bool`',
          pos,
        );
      }
      return const PrimType(PrimKind.bool_);
    }

    final unified = _unifyNumeric(lt, rt, pos);
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
    return const PrimType(PrimKind.bool_);
  }

  KlinType _unifyNumeric(KlinType lt, KlinType rt, SourcePos pos) {
    if (lt is UntypedInt && rt is UntypedInt) {
      return const UntypedInt();
    } else if (lt is UntypedFloat && rt is UntypedFloat) {
      return const UntypedFloat();
    } else if (lt is UntypedInt && rt is UntypedFloat) {
      return const UntypedFloat();
    } else if (lt is UntypedFloat && rt is UntypedInt) {
      return const UntypedFloat();
    } else if (lt is UntypedInt && rt is PrimType && rt.kind.isInteger) {
      return rt;
    } else if (rt is UntypedInt && lt is PrimType && lt.kind.isInteger) {
      return lt;
    } else if (lt is UntypedFloat && rt is PrimType && rt.kind.isFloat) {
      return rt;
    } else if (rt is UntypedFloat && lt is PrimType && lt.kind.isFloat) {
      return lt;
    } else if (lt is UntypedInt && rt is PrimType && rt.kind.isFloat) {
      return rt;
    } else if (rt is UntypedInt && lt is PrimType && lt.kind.isFloat) {
      return lt;
    } else if (lt == rt) {
      return lt;
    } else {
      throw CheckError(
        'niezgodność typów: `${lt.displayName}` i `${rt.displayName}`',
        pos,
      );
    }
  }

  /// Ustawia konkretny typ na wyrażeniu (i rekurencyjnie na poddrzewie
  /// tam, gdzie były literały untyped).
  void _materialize(Expr expr, KlinType type) {
    expr.resolvedType = type;
    switch (expr) {
      case UnaryExpr(:final operand):
        _materialize(operand, type);
      case BinaryExpr(:final left, :final right, :final op):
        if (_cmpOps.contains(op)) {
          // Operandy porównania mają typ liczbowy; wynik bool jest na węźle.
          // Przy materializacji bool z góry nie schodzimy — typ operandów
          // został ustawiony w _inferComparison.
          break;
        }
        _materialize(left, type);
        _materialize(right, type);
      case GroupExpr(:final inner):
        _materialize(inner, type);
      case IntLit() ||
            FloatLit() ||
            BoolLit() ||
            StringLit() ||
            NameExpr():
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
      StrType() => throw CheckError(
          'nie można użyć napisu w tym kontekście',
          pos,
        ),
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
