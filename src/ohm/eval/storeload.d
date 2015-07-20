module ohm.eval.storeload;


import std.stdio;

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

	override Status visit(ref ir.Exp exp, ir.ExpReference expRef)
	{
		auto var = cast(ir.Variable) expRef.decl;
		if (mReplFuncLevel == 0 || var is null || !varStore.has(var.name))
			return Continue;

		auto loc = expRef.location;

		// replace any unidentifier identifier with a call to __ohm_load
		auto fn = lookupFunction(lp, thisModule, loc, "__ohm_load");
		exp = buildCall(loc, fn, [
			buildConstantSizeT(loc, lp, 1),
			buildAccess(loc, buildConstantString(loc, var.name), "ptr"),
		], fn.name);

		return Continue;
	}
}