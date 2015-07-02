module ohm.volta.controller;

import std.algorithm : remove;
import std.stdio : write, writeln, writefln, writef;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;
import volt.interfaces : Controller, Frontend, Backend, Settings, LanguagePass, Pass, TargetType;
import volt.semantic.languagepass : VoltLanguagePass;
import volt.semantic.util;
import volt.token.location : Location;
import volt.visitor.prettyprinter : PrettyPrinter;
import volt.visitor.debugprinter : DebugPrinter, DebugMarker;
import volt.llvm.interfaces : State;

import ohm.volta.parser : OhmParser = Parser;
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
	ir.Function mMainFunc;
	ir.Exp returnedExp;

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
		mModule.name = qname;
		Location loc;
		loc.filename = "main";
		mModule.location = loc;
		mModule.children = new ir.TopLevelBlock();
		mModule.children.nodes = [];

		this.mMainFunc = new ir.Function();
		mMainFunc.name = "__ohm_main";
		loc.filename = "__ohm_main";
		mMainFunc.type = new ir.FunctionType();
		mMainFunc.type.ret = new ir.PrimitiveType(ir.PrimitiveType.Kind.Void);
		mMainFunc.type.ret.location = loc;
		mMainFunc.location = loc;
		mMainFunc.params = [];
		mMainFunc.type.location = mMainFunc.location;
		mMainFunc._body = new ir.BlockStatement();
		mMainFunc.location = loc;
	}

	this(Settings s)
	{
		this.settings = s;

		auto p = new OhmParser();
		auto lp = new VoltLanguagePass(s, p, this);
		auto b = new OhmBackend(lp);

		this(s, p, lp, b);

		debugVisitors ~= new DebugMarker("Running DebugPrinter:");
		debugVisitors ~= new DebugPrinter();
		debugVisitors ~= new DebugMarker("Running PrettyPrinter:");
		debugVisitors ~= new PrettyPrinter();
	}

	void addTopLevel(string statements, Location loc)
	{
		auto tld = (cast(OhmParser)this.frontend).parseToplevel(statements, loc);
		mModule.children.nodes ~= tld.nodes;
	}

	void addStatement(string statements, Location loc)
	{
		auto nodes = frontend.parseStatements(statements, loc);

		// remove the last return statement
		ir.Node old = null;
		if (mMainFunc._body.statements.length) {
			old = mMainFunc._body.statements[$-1];
			mMainFunc._body.statements = mMainFunc._body.statements.remove(mMainFunc._body.statements.length-1);
		}

		/*if (old && cast(ir.ReturnStatement) old) {
			ir.Exp exp = (cast(ir.ReturnStatement) old).exp;

			if (cast(ir.BinOp) exp) {
				mMainFunc._body.statements ~= copyExp(exp);
			}
		}*/

		mMainFunc._body.statements ~= nodes[0..$-1];

		ir.ExpStatement exp;
		if ((exp = cast(ir.ExpStatement)nodes[$-1]) !is null) {
			returnedExp = exp.exp;
		} else {
			mMainFunc._body.statements ~= nodes[$-1];
			returnedExp = null;
		}

		auto ret = new ir.ReturnStatement();
		ret.exp = returnedExp;
		mMainFunc._body.statements ~= ret;
	}

	ir.Module getModule(ir.QualifiedName name)
	{
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
		ir.Module testMod = copy(mModule);
		ir.Function testFunc = copy(mMainFunc);
		testMod.children.nodes ~= testFunc;

		ir.Module[] mods = [testMod] /* ~ moreModules */;

		bool debugPassesRun = false;
		void debugPasses(ir.Module[] mods)
		{
			if (!debugPassesRun && settings.internalDebug) {
				debugPassesRun = true;
				foreach(pass; debugVisitors) {
					foreach(mod; mods) {
						pass.transform(mod);
					}
				}
			}
		}
		scope(exit) debugPasses(mods);

		// Force phase 1 to be executed on the modules.
		foreach (mod; mods)
			languagePass.phase1(mod);

		// adjust the return type of our magic function
		if (returnedExp) {
			testFunc.type.ret = copyTypeSmart(testFunc.location, getExpType(languagePass, copyExp(returnedExp), testFunc.myScope));
		} else {
			testFunc.type.ret = new ir.PrimitiveType(ir.PrimitiveType.Kind.Void);
			testFunc.type.ret.location = testFunc.location;
		}

		// All modules need to be run trough phase2.
		languagePass.phase2(mods);


		testFunc.mangledName = testFunc.name;

		// All modules need to be run trough phase3.
		languagePass.phase3(mods);

		debugPasses(mods);

		// TODO link with other modules, returned by getModule
		OhmBackend ob = cast(OhmBackend)backend;
		// mods[0] is our mModule
		return ob.getCompiledModuleState(mods[0]);
	}
}