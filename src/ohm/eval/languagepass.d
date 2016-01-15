module ohm.eval.languagepass;


import volt.util.worktracker;

import volt.semantic.extyper;
import volt.postparse.gatherer;
import volt.semantic.irverifier;
import volt.postparse.condremoval;
import volt.lowerer.newreplacer;
import volt.lowerer.llvmlowerer;
import volt.lowerer.manglewriter;
import volt.postparse.attribremoval;
import volt.lowerer.typeidreplacer;
import volt.postparse.scopereplacer;
import volt.semantic.cfg;
import volt.semantic.strace;

import volt.interfaces;
import volt.semantic.languagepass : VoltLanguagePass;

import ohm.eval.storeload;
import ohm.eval.vardeclinserter;


class OhmLanguagePass : VoltLanguagePass
{
public:
	this(Driver driver, VersionSet ver, Settings settings, Frontend frontend)
	{
		super(driver, ver, settings, frontend);
	}

	override void reset() {
		mTracker = new WorkTracker();

		postParse = [];
		postParse ~= new ConditionalRemoval(ver);
		if (settings.removeConditionalsOnly) {
			return;
		}
		postParse ~= new ScopeReplacer();
		postParse ~= new AttribRemoval(settings);
		postParse ~= new VarDeclInserter(this);
		postParse ~= new Gatherer();

		passes2 = [];
		passes2 ~= new SimpleTrace(this);
		passes2 ~= new ExTyper(this);
		passes2 ~= new CFGBuilder(this);
		passes2 ~= new IrVerifier();

		passes3 = [];
		passes3 ~= new LlvmLowerer(this);
		passes3 ~= new StoreLoad(this);
		passes3 ~= new NewReplacer(this);
		passes3 ~= new TypeidReplacer(this);
		passes3 ~= new MangleWriter(this);
		passes3 ~= new IrVerifier();
	}
}