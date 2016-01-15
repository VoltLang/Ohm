module ohm.eval.vardeclinserter;


import ir = volt.ir.ir;
import volt.ir.util;
import volt.interfaces;
import volt.visitor.visitor;
import volt.semantic.classify : size;

import ohm.eval.driver : OhmDriver;
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
				if (varStore.willInitLater(val.name))
					continue;

				auto asTR = cast(ir.TypeReference)val.type;
				if (asTR !is null) {
					asTR.type = null;
				}

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
			varStore.initLater(d.name);
		}

		return Continue;
	}

public:
	this(OhmLanguagePass lp)
	{
		this.lp = lp;

		auto driver = cast(OhmDriver)lp.driver;
		assert(driver !is null);
		this.varStore = driver.varStore;
	}
}