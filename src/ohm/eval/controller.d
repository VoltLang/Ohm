module ohm.eval.controller;

import std.algorithm : remove, endsWith;
import std.path : dirSeparator;
import std.file : remove, exists;
import std.process : wait, spawnShell;
import std.stdio : write, writeln, writefln, writef;
import core.stdc.stdint : int64_t;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;
import volt.util.path;
import volt.interfaces : Controller, Frontend, Backend, LanguagePass, Pass, TargetType;
import volt.semantic.languagepass : VoltLanguagePass;
import volt.semantic.extyper : ExTyper;
import volt.semantic.util;
import volt.token.location : Location;
import volt.parser.toplevel : createImport;
import volt.visitor.visitor : accept;
import volt.visitor.prettyprinter : PrettyPrinter;
import volt.visitor.debugprinter : DebugPrinter, DebugMarker;
import volt.llvm.interfaces : State;
import volt.llvm.backend : loadModule;
import volt.errors;

import lib.llvm.executionengine;
import lib.llvm.analysis;
import lib.llvm.core;
import lib.llvm.support;

import ohm.settings : Settings;
import ohm.eval.parser : OhmParser;
import ohm.eval.backend : OhmBackend;
import ohm.eval.datastore : VariableStore;
import ohm.eval.languagepass : OhmLanguagePass;
import ohm.eval.util : createSimpleModule, createSimpleFunction, addImport;


class OhmController : Controller
{
public:
	Settings settings;
	OhmParser frontend;
	OhmLanguagePass languagePass;
	OhmBackend backend;
	VariableStore varStore;

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
		this.varStore = new VariableStore();

		this.mIncludes = settings.stdIncludePaths;
		mIncludes ~= settings.includePaths;

		// LLVM setup
		LLVMLinkInMCJIT();

		foreach (lib; settings.libraryFiles) {
			LLVMLoadLibraryPermanently(toStringz(lib));
		}

		// AST setup
		this.mModule = createSimpleModule(["ohm"]);
		addImport(mModule, ["defaultsymbols"], false);
		addImport(mModule, ["object"], true);

		auto tlb = frontend.parseToplevel("
			extern(C) {
				void __ohm_store(size_t id, const(char)* varName, int value);
				int __ohm_load(size_t id, const(char)* varName);
			}
		", Location());
		mModule.children.nodes ~= tlb.nodes;

		// main function which works as a scope and
		// will actually be called by the JIT
		this.mREPLFunc = createSimpleFunction("__ohm_main");
		// the extyper will automatically set the correct return type
		mREPLFunc.isAutoReturn = true;

		// the runtime expects a main function, without this
		// function we would get linker errors (from the JIT).
		mModule.children.nodes ~= createSimpleFunction("main");
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

	void addTopLevel(ir.TopLevelBlock tlb)
	{
		mModule.children.nodes ~= tlb.nodes;
	}

	void addStatement(ir.Node[] nodes)
	{
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
		scope(exit) debugPasses([copiedMod]);

		// reset leftover state
		languagePass.reset();

		// After we have loaded all of the modules
		// setup the pointers, this allows for suppling
		// a user defined object module.
		languagePass.setupOneTruePointers();

		// Force phase 1 to be executed on the modules.
		foreach (mod; mods)
			languagePass.phase1(mod);

		// add other modules used by the main module
		mods ~= mModulesByName.values;

		// All modules need to be run trough phase2.
		languagePass.phase2(mods);

		// make sure we don't use a mangled name
		copiedREPLFunc.mangledName = copiedREPLFunc.name;

		// All modules need to be run trough phase3.
		languagePass.phase3(mods);

		debugPasses([copiedMod]);

		return backend.getCompiledModuleState(copiedMod);
	}

	string execute(State state)
	{
		scope(exit) state.close();

		string error;
		LLVMExecutionEngineRef ee = null;
		assert(LLVMCreateMCJITCompilerForModule(&ee, state.mod, null, 0, error) == 0, error);

		foreach (path; settings.stdFiles) {
			auto mod = loadModule(LLVMContextCreate(), path);
			LLVMAddModule(ee, mod);
		}

		// workaround which calls ee->finalizeObjects, which makes
		// LLVMRunStaticConstructors not segfault
		LLVMDisposeGenericValue(LLVMRunFunction(ee, "vmain", []));
		LLVMRunStaticConstructors(ee);

		LLVMValueRef func;
		assert(LLVMFindFunction(ee, "__ohm_main", &func) == 0);
		LLVMGenericValueRef val = LLVMRunFunction(ee, func, 0, null);
		scope(exit) LLVMDisposeGenericValue(val);

		return to!string(cast(int64_t)LLVMGenericValueToInt(val, true));
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