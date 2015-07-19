module ohm.eval.languagepass;


import volt.util.worktracker;

import volt.semantic.extyper;
import volt.semantic.gatherer;
import volt.semantic.irverifier;
import volt.semantic.condremoval;
import volt.semantic.newreplacer;
import volt.semantic.llvmlowerer;
import volt.semantic.manglewriter;
import volt.semantic.attribremoval;
import volt.semantic.typeidreplacer;
import volt.semantic.importresolver;
import volt.semantic.ctfe;
import volt.semantic.cfg;

import volt.semantic.resolver;
import volt.semantic.classresolver;
import volt.semantic.aliasresolver;
import volt.semantic.userattrresolver;
import volt.semantic.strace;

import volt.interfaces;
import volt.semantic.languagepass : VoltLanguagePass;

import ohm.eval.storeload;


class OhmLanguagePass : VoltLanguagePass
{
public:
	this(Settings settings, Frontend frontend, Controller controller)
	{
		super(settings, frontend, controller);
	}

	override void reset() {
		mTracker = new WorkTracker();

		postParse = [];
		postParse ~= new ConditionalRemoval(this);
		if (settings.removeConditionalsOnly) {
			return;
		}
		postParse ~= new AttribRemoval(this);
		postParse ~= new Gatherer(this);

		passes2 = [];
		passes2 ~= new SimpleTrace(this);
		passes2 ~= new StoreLoad(this);
		passes2 ~= new ExTyper(this);
		passes2 ~= new CFGBuilder(this);
		passes2 ~= new IrVerifier();

		passes3 = [];
		passes3 ~= new LlvmLowerer(this);
		passes3 ~= new NewReplacer(this);
		passes3 ~= new TypeidReplacer(this);
		passes3 ~= new MangleWriter(this);
		passes3 ~= new IrVerifier();
	}
}