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


class StoreLoad : NullVisitor, Pass
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
			mReplFuncLevel += 1;
		}

		return Continue;
	}

	override Status leave(ir.Function fn)
	{
		if (fn.isAutoReturn) {
			mReplFuncLevel -= 1;
		}

		return Continue;
	}

	override Status enter(ir.Variable d)
	{
		if (mReplFuncLevel == 0)
			return Continue;

		varStore.init(d.name, d.type);

		return Continue;
	}
	//override Status leave(ir.Variable d);

	override Status visit(ref ir.Exp exp, ir.IdentifierExp identExp)
	{
		if (mReplFuncLevel == 0 || !varStore.has(identExp.value))
			return Continue;

		auto loc = exp.location;

		// replace any unidentifier identifier with a call to __ohm_load
		auto fn = lookupFunction(lp, thisModule, identExp.location, "__ohm_load");
		exp = buildCall(loc, fn, [buildConstantSizeT(loc, lp, 1), buildConstantString(loc, identExp.value)], fn.name);

		return Continue;
	}
}