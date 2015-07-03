module ohm.volta.languagepass;


import ir = volt.ir.ir;
import volt.interfaces : Settings, Frontend, Controller;
import volt.semantic.languagepass : VoltLanguagePass;
import volt.semantic.extyper : ExTyper;

import ohm.volta.extyper : REPLExTyper;



class OhmLanguagePass : VoltLanguagePass
{
public:
	this(Settings settings, Frontend frontend, Controller controller)
	{
		super(settings, frontend, controller);
	}

	void setREPLFunction(ir.Function fn)
	{
		// TODO: figure out how to make this prettier, maybe
		// a way to access every Pass by name?
		foreach(size_t i, pass; passes2) {
			if (auto et = cast(REPLExTyper) pass) {
				et.setREPLFunction(fn);
			}
		}
	}

	override ExTyper getExTyper()
	{
		return new REPLExTyper(this);
	}
}