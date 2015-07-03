module ohm.volta.extpyer;


import ir = volt.ir.ir;
import volt.ir.util : copyTypeSmart;
import volt.interfaces : LanguagePass;
import volt.semantic.extyper;
import volt.semantic.util;
import volt.semantic.classify;
import volt.semantic.typer;
import volt.visitor.visitor;
import volt.errors;

import std.stdio;


class REPLExTyper : ExTyper
{
protected:
	ir.Function mREPLFunc;

public:
	this(LanguagePass lp)
	{
		super(lp);
	}

	void setREPLFunction(ir.Function fn)
	{
		mREPLFunc = fn;
	}

	override Status enter(ir.ReturnStatement ret)
	{
		auto fn = getParentFunction(ctx.current);
		if (fn is null) {
			throw panic(ret, "return statement outside of function.");
		}

		if (ret.exp !is null) {
			acceptExp(ret.exp, this);
			auto retType = getExpType(ctx.lp, ret.exp, ctx.current);
			if (fn is mREPLFunc) {
				fn.type.ret = copyTypeSmart(retType.location, getExpType(ctx.lp, ret.exp, ctx.current));
			}
			auto st = cast(ir.StorageType)retType;
			if (st !is null && st.type == ir.StorageType.Kind.Scope && mutableIndirection(st)) {
				throw makeNoReturnScope(ret.location);
			}
			extypeAssign(ctx, ret.exp, fn.type.ret);
		} else if (!isVoid(realType(fn.type.ret))) {
			// No return expression on function returning a value.
			throw makeReturnValueExpected(ret.location, fn.type.ret);
		}

		return ContinueParent;
	}
}