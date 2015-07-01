module ohm.volta.controller;

import ir = volt.ir.ir;
import volt.interfaces : Controller, Frontend, Backend, Settings, LanguagePass, Pass, TargetType;
import volt.semantic.languagepass : VoltLanguagePass;
import volt.token.location : Location;
import volt.visitor.prettyprinter : PrettyPrinter;
import volt.visitor.debugprinter : DebugPrinter, DebugMarker;
import volt.llvm.interfaces : State;

import ohm.volta.parser : Parser;
import ohm.volta.backend : OhmBackend;



class OhmController : Controller {
public:
	Settings settings;
	Frontend frontend;
	LanguagePass languagePass;
	Backend backend;

	Pass[] debugVisitors;

private:
	ir.Module mModule;

public:
	this(Settings s, Frontend f, LanguagePass lp, Backend b)
	{
		this.settings = s;
		this.frontend = f;
		this.languagePass = lp;
		this.backend = b;

		this.mModule = new ir.Module();
		auto qname = new ir.QualifiedName();
		qname.identifiers = [new ir.Identifier("ohm")];
		this.mModule.name = qname;
		Location loc;
		loc.filename = "main";
		this.mModule.location = loc;
		this.mModule.children = new ir.TopLevelBlock();
		this.mModule.children.nodes = [];
	}

	this(Settings s)
	{
		this.settings = s;

		auto p = new Parser();
		p.dumpLex = false;
		auto lp = new VoltLanguagePass(s, p, this);
		auto b = new OhmBackend(lp);

		this(s, p, lp, b);

		debugVisitors ~= new DebugMarker("Running DebugPrinter:");
		debugVisitors ~= new DebugPrinter();
		debugVisitors ~= new DebugMarker("Running PrettyPrinter:");
		debugVisitors ~= new PrettyPrinter();
	}

	void addTopLevel(string statements, Location loc) {
		auto tld = (cast(Parser)this.frontend).parseToplevel(statements, loc);
		mModule.children.nodes ~= tld.nodes;
	}

	ir.Module getModule(ir.QualifiedName name) {
		// TODO
		return new ir.Module();
	}

	void close() {
		frontend.close();
		languagePass.close();
		backend.close();

		settings = null;
		frontend = null;
		languagePass = null;
		backend = null;
	}

	State compile() {
		// TODO
		ir.Module[] mods = [mModule] /* ~ moreModules */;

		bool debugPassesRun = false;
		void debugPasses()
		{
			if (!debugPassesRun) {
				debugPassesRun = true;
				foreach(pass; debugVisitors) {
					foreach(mod; mods) {
						pass.transform(mod);
					}
				}
			}
		}
		scope(exit) debugPasses();

		// Force phase 1 to be executed on the modules.
		foreach (mod; mods)
			languagePass.phase1(mod);

		// All modules need to be run trough phase2.
		languagePass.phase2(mods);

		// All modules need to be run trough phase3.
		languagePass.phase3(mods);

		debugPasses();

		// TODO link with other modules, returned by getModule
		OhmBackend ob = cast(OhmBackend)backend;
		// mods[0] is our mModule
		return ob.getCompiledModuleState(mods[0]);
	}
}