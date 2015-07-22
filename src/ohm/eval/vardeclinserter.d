module ohm.eval.vardeclinserter;


import std.algorithm : canFind;

import volt.ir.util;
import ir = volt.ir.ir;
import volt.interfaces;
import volt.visitor.visitor;
import volt.semantic.classify : size;

import ohm.eval.controller : OhmController;
import ohm.eval.languagepass : OhmLanguagePass;
import ohm.eval.datastore : VariableStore;


class VarDeclInserter : NullVisitor, Pass
{
public:
	LanguagePass lp;
	VariableStore varStore;
	ir.Module thisModule;

protected:
	size_t mReplFuncLevel = 0;
	string[] mIgnore;

public:
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

		return Continue;
	}

	override Status leave(ir.Function fn)
	{
		if (fn.isAutoReturn && mReplFuncLevel == 1) {
			ir.Node[] decls;
			foreach (val; varStore.values()) {
				if (canFind(mIgnore, val.name))
					continue;

				decls ~= buildVariable(fn.location, val.type, ir.Variable.Storage.Function, val.name);
			}

			fn._body.statements = decls ~ fn._body.statements;
		}

		if (fn.isAutoReturn) {
			--mReplFuncLevel;
		}

		return Continue;
	}

	override Status enter(ir.Variable d)
	{
		if (mReplFuncLevel != 0) {
			varStore.init(d.name, d.type, size(lp, d.type));
			mIgnore ~= d.name;
		}

		return Continue;
	}

public:
	this(OhmLanguagePass lp)
	{
		this.lp = lp;

		auto controller = cast(OhmController)lp.controller;
		assert(controller !is null);
		this.varStore = controller.varStore;
	}
}