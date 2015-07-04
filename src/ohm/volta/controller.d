module ohm.volta.controller;

import std.algorithm : remove, endsWith;
import std.path : dirSeparator;
import std.file : remove, exists;
import std.process : wait, spawnShell;
import std.stdio : write, writeln, writefln, writef;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;
import volt.util.path;
import volt.interfaces : Controller, Frontend, Backend, Settings, LanguagePass, Pass, TargetType;
import volt.semantic.languagepass : VoltLanguagePass;
import volt.semantic.extyper : ExTyper;
import volt.semantic.util;
import volt.token.location : Location;
import volt.parser.toplevel : createImport;
import volt.visitor.visitor : accept;
import volt.visitor.prettyprinter : PrettyPrinter;
import volt.visitor.debugprinter : DebugPrinter, DebugMarker;
import volt.llvm.interfaces : State;
import volt.errors;

import ohm.volta.parser : OhmParser;
import ohm.volta.backend : OhmBackend;
import ohm.volta.languagepass : OhmLanguagePass;
import ohm.volta.extyper : REPLExTyper;



class OhmController : Controller
{
public:
	Settings settings;
	OhmParser frontend;
	OhmLanguagePass languagePass;
	OhmBackend backend;

	Pass[] debugVisitors;

protected:
	ir.Module mModule;
	ir.Function mREPLFunc;

	string[] mIncludes;
	ir.Module[string] mModulesByName;
	ir.Module[string] mModulesByFile;

protected:
	this(Settings s, OhmParser f, OhmLanguagePass lp, OhmBackend b)
	{
		this.settings = s;
		this.frontend = f;
		this.languagePass = lp;
		this.backend = b;

		this.mIncludes = settings.stdIncludePaths;
		mIncludes ~= settings.includePaths;

		this.mModule = new ir.Module();
		auto qname = new ir.QualifiedName();
		qname.identifiers = [new ir.Identifier("ohm")];
		mModule.name = qname;
		Location loc;
		loc.filename = "main";
		mModule.location = loc;
		mModule.children = new ir.TopLevelBlock();
		mModule.children.nodes = [
			createImport(mModule.location, "defaultsymbols", false),
			createImport(mModule.location, "object", true)
		];

		this.mREPLFunc = new ir.Function();
		mREPLFunc.name = "__ohm_main";
		loc.filename = "__ohm_main";
		mREPLFunc.type = new ir.FunctionType();
		mREPLFunc.type.ret = new ir.PrimitiveType(ir.PrimitiveType.Kind.Void);
		mREPLFunc.type.ret.location = loc;
		mREPLFunc.location = loc;
		mREPLFunc.params = [];
		mREPLFunc.type.location = mREPLFunc.location;
		mREPLFunc._body = new ir.BlockStatement();
		mREPLFunc.location = loc;

		auto fakeMain = new ir.Function();
		fakeMain.name = "main";
		loc.filename = "fakeMain";
		fakeMain.type = new ir.FunctionType();
		fakeMain.type.ret = new ir.PrimitiveType(ir.PrimitiveType.Kind.Void);
		fakeMain.type.ret.location = loc;
		fakeMain.location = loc;
		fakeMain.params = [];
		fakeMain.type.location = fakeMain.location;
		fakeMain._body = new ir.BlockStatement();
		fakeMain.location = loc;

		mModule.children.nodes ~= fakeMain;
	}

public:
	this(Settings s)
	{
		this.settings = s;

		auto p = new OhmParser();
		auto lp = new OhmLanguagePass(s, p, this);
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

		auto lastNode = nodes[$-1];
		auto otherNodes = nodes[0..$-1];

		// remove the last return statement
		ir.Node oldLastNode = null;
		if (mREPLFunc._body.statements.length) {
			oldLastNode = mREPLFunc._body.statements[$-1];
			--mREPLFunc._body.statements.length; // cut off the last element
		}

		/*if (old && cast(ir.ReturnStatement) old) {
			ir.Exp exp = (cast(ir.ReturnStatement) old).exp;

			if (cast(ir.BinOp) exp) {
				mREPLFunc._body.statements ~= copyExp(exp);
			}
		}*/

		mREPLFunc._body.statements ~= otherNodes;

		ir.Exp exp = null;
		if (auto expStmt = cast(ir.ExpStatement)lastNode) {
			exp = expStmt.exp;
		} else {
			mREPLFunc._body.statements ~= lastNode;
		}

		auto ret = new ir.ReturnStatement();
		ret.exp = exp;
		mREPLFunc._body.statements ~= ret;
	}

	ir.Module getModule(ir.QualifiedName name)
	{
		auto p = name.toString() in mModulesByName;
		ir.Module m;

		if (p !is null)
			m = *p;

		string[] validPaths;
		foreach (path; mIncludes) {
			if (m !is null)
				break;

			auto paths = genPossibleFilenames(path, name.strings);

			foreach (possiblePath; paths) {
				if (exists(possiblePath)) {
					validPaths ~= possiblePath;
				}
			}
		}

		if (m is null) {
			if (validPaths.length == 0) {
				return null;
			}
			if (validPaths.length > 1) {
				throw makeMultipleValidModules(name, validPaths);
			}
			m = loadAndParse(validPaths[0]);
		}

		// Need to make sure that this module can
		// be used by other modules.
		if (m !is null) {
			languagePass.phase1(m);
		}

		return m;
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
		// make copies so wen can reuse the AST later on
		auto copiedMod = copy(mModule);
		auto copiedREPLFunc = copy(mREPLFunc);
		copiedMod.children.nodes ~= copiedREPLFunc;

		ir.Module[] mods = [copiedMod];

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

		// After we have loaded all of the modules
		// setup the pointers, this allows for suppling
		// a user defined object module.
		languagePass.setupOneTruePointers();

		// Force phase 1 to be executed on the modules.
		foreach (mod; mods)
			languagePass.phase1(mod);

		// add other modules used by the main module
		mods ~= mModulesByName.values;

		// make the ExTyper aware of the REPL-Function
		// it will fix the return type automatically
		languagePass.setREPLFunction(copiedREPLFunc);

		// All modules need to be run trough phase2.
		languagePass.phase2(mods);

		// make sure we don't use a mangled name
		copiedREPLFunc.mangledName = copiedREPLFunc.name;

		// All modules need to be run trough phase3.
		languagePass.phase3(mods);

		debugPasses(mods);

		return backend.getCompiledModuleState(copiedMod);
	}

protected:
	ir.Module loadAndParse(string file)
	{
		Location loc;
		loc.filename = file;

		if (file in mModulesByFile) {
			return mModulesByFile[file];
		}

		auto src = cast(string) read(loc.filename);
		auto m = frontend.parseNewFile(src, loc);
		if (m.name.toString() in mModulesByName) {
			throw makeAlreadyLoaded(m, file);
		}

		mModulesByFile[file] = m;
		mModulesByName[m.name.toString()] = m;

		return m;
	}
}