module ohm.eval.storeload;


import std.stdio;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.interfaces;
import volt.semantic.lookup;
import volt.visitor.visitor;
import volt.visitor.scopemanager;

import ohm.eval.util : lookupFunction;


class StoreLoad : NullVisitor, Pass
{
public:
	LanguagePass lp;
	ir.Module thisModule;

protected:
	size_t replFuncLevel = 0;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
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
			replFuncLevel += 1;
		}

		return Continue;
	}

	override Status leave(ir.Function fn)
	{
		if (fn.isAutoReturn) {
			replFuncLevel -= 1;
		}

		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.IdentifierExp identExp)
	{
		if (replFuncLevel == 0)
			return Continue;

		auto loc = exp.location;

		auto store = lookup(lp, thisModule.myScope, loc, identExp.value);
		if (store !is null)
			return Continue;

		// replace any unidentifier identifier with a call to __ohm_load
		auto fn = lookupFunction(lp, thisModule, identExp.location, "__ohm_load");
		exp = buildCall(loc, fn, [buildConstantSizeT(loc, lp, 1), buildConstantString(loc, identExp.value)], fn.name);

		return Continue;
	}
}