module ohm.eval.storeload;


import ir = volt.ir.ir;
import volt.ir.util;
import volt.interfaces;
import volt.semantic.lookup;
import volt.visitor.visitor;
import volt.visitor.scopemanager;

import ohm.eval.datastore : VariableStore;
import ohm.eval.controller : OhmController;
import ohm.eval.languagepass : OhmLanguagePass;
import ohm.eval.util : lookupFunction;


class StoreLoad : ScopeManager, Pass
{
public:
	LanguagePass lp;
	VariableStore varStore;
	ir.Module thisModule;

protected:
	size_t mReplFuncLevel = 0;

public:
	this(OhmLanguagePass lp)
	{
		this.lp = lp;

		auto controller = cast(OhmController)lp.controller;
		assert(controller !is null);
		this.varStore = controller.varStore;
	}

	override void transform(ir.Module m)
	{
		thisModule = m;
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ir.Function fn)
	{
		if (fn.isAutoReturn) {
			++mReplFuncLevel;
		}

		return super.enter(fn);
	}

	override Status leave(ir.Function fn)
	{
		if (fn.isAutoReturn) {
			--mReplFuncLevel;
		}

		return super.leave(fn);
	}

	override Status enter(ref ir.Exp exp, ir.BinOp binOp)
	{
		if (mReplFuncLevel == 0)
			return Continue;

		switch(binOp.op) with(ir.BinOp.Op) {
		case AddAssign:
		case SubAssign:
		case MulAssign:
		case DivAssign:
		case ModAssign:
		case AndAssign:
		case OrAssign:
		case XorAssign:
		case CatAssign:
		case LSAssign:  // <<=
		case SRSAssign:  // >>=
		case RSAssign: // >>>=
		case PowAssign:
		case Assign:
			auto asExpRef = cast(ir.ExpReference) binOp.left;
			if (asExpRef is null)
				return Continue;

			auto var = cast(ir.Variable) asExpRef.decl;
			if (var is null || !varStore.has(var.name))
				return Continue;

			acceptExp(binOp.right, this);

			if (binOp.op == ir.BinOp.Op.Assign) {
				return handleAssign(exp, binOp, var);
			} else {
				return handleOpAssign(exp, binOp, var);
			}
		default:
			return Continue;
		}
	}

	Status handleAssign(ref ir.Exp exp, ir.BinOp binOp, ir.Variable var)
	{
		auto loc = binOp.location;
		auto fn = lookupFunction(lp, thisModule, loc, "__ohm_store");

		exp = buildCall(loc, fn, [
			buildConstantSizeT(loc, lp, cast(int) varStore.id),
			buildAccess(loc, buildConstantString(loc, var.name), "ptr"),
			binOp.right
		], fn.name);

		return Continue;
	}

	Status handleOpAssign(ref ir.Exp exp, ir.BinOp binOp, ir.Variable var)
	{
		auto loc = binOp.location;
		auto storeFn = lookupFunction(lp, thisModule, loc, "__ohm_store");
		auto loadFn = lookupFunction(lp, thisModule, loc, "__ohm_load");

		auto statExp = buildStatementExp(loc);

		auto tmp = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
			copyTypeSmart(loc, var.type), buildCall(loc, loadFn, [
				buildConstantSizeT(loc, lp, cast(int) varStore.id),
				buildAccess(loc, buildConstantString(loc, var.name), "ptr"),
			], loadFn.name)
		);

		buildExpStat(loc, statExp,
			buildBinOp(loc, binOp.op,
				buildExpReference(loc, tmp, tmp.name),
				binOp.right
			)
		);

		auto storeCall = buildCall(loc, storeFn, [
			buildConstantSizeT(loc, lp, cast(int) varStore.id),
			buildAccess(loc, buildConstantString(loc, var.name), "ptr"),
			buildExpReference(loc, tmp, tmp.name)
		], storeFn.name);

		statExp.exp = storeCall;
		exp = statExp;

		return Continue;
	}


	override Status visit(ref ir.Exp exp, ir.ExpReference expRef)
	{
		auto var = cast(ir.Variable) expRef.decl;
		if (mReplFuncLevel == 0 || var is null || !varStore.has(var.name))
			return Continue;

		auto loc = expRef.location;

		// replace any unidentifier identifier with a call to __ohm_load
		auto fn = lookupFunction(lp, thisModule, loc, "__ohm_load");
		exp = buildCall(loc, fn, [
			buildConstantSizeT(loc, lp, cast(int) varStore.id),
			buildAccess(loc, buildConstantString(loc, var.name), "ptr"),
		], fn.name);

		return Continue;
	}
}