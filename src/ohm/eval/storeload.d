module ohm.eval.storeload;


import ir = volt.ir.ir;
import volt.ir.util;
import volt.interfaces;
import volt.semantic.lookup;
import volt.semantic.classify;
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

	override Status enter(ir.ReturnStatement ret)
	{
		auto fn = getParentFunction(current);
		if (!fn.isAutoReturn)
			return Continue;

		varStore.initReturn(fn.type.ret);

		if (ret.exp is null)
			return Continue;

		auto loc = ret.location;
		auto owning = cast(ir.BlockStatement) current.node;
		assert(owning !is null);

		auto fnRetPtr = lookupFunction(lp, thisModule, loc, "__ohm_get_return_pointer");
		auto retVar = buildDeref(loc, buildCastSmart(
			loc, buildPtrSmart(loc, fn.type.ret), buildCall(
				loc, fnRetPtr, [buildConstantSizeT(loc, lp, cast(int) varStore.id)], fnRetPtr.name
			)
		));
		acceptExp(ret.exp, this);
		auto assignStmt = buildExpStat(loc, buildAssign(loc, retVar, ret.exp));

		ret.exp = null;
		fn.type.ret = buildVoid(loc);
		owning.statements = owning.statements[0..$-1] ~ assignStmt ~ ret;

		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.ExpReference expRef)
	{
		auto var = cast(ir.Variable) expRef.decl;
		if (mReplFuncLevel == 0 || var is null || !varStore.has(var.name))
			return Continue;

		// replace any unidentified identifier with a call to __ohm_get_pointer

		auto loc = expRef.location;
		auto fn = lookupFunction(lp, thisModule, loc, "__ohm_get_pointer");
		auto type = varStore.get(var.name).type;

		exp = buildDeref(loc, buildCastSmart(
			loc, buildPtrSmart(loc, type), buildCall(
				loc, fn, [
					buildConstantSizeT(loc, lp, cast(int) varStore.id),
					buildAccess(loc, buildConstantString(loc, var.name), "ptr"),
				], fn.name
			)
		));

		return Continue;
	}
}