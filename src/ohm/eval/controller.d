module ohm.eval.controller;

import std.algorithm : endsWith;
import std.path : buildNormalizedPath;
import std.file : exists;
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
import volt.semantic.classify : isAssign;
import volt.semantic.util;
import volt.token.location : Location;
import volt.parser.toplevel : createImport;
import volt.visitor.visitor : accept;
import volt.visitor.prettyprinter : PrettyPrinter;
import volt.visitor.debugprinter : DebugPrinter, DebugMarker;
import volt.llvm.interfaces : State;
import volt.llvm.backend : loadModule;
import volt.errors : makeMultipleValidModules, makeAlreadyLoaded;
import volt.exceptions : CompilerError;

import lib.llvm.executionengine;
import lib.llvm.analysis;
import lib.llvm.core;
import lib.llvm.support;

import ohm.settings : Settings;
import ohm.interfaces : VariableData;
import ohm.read.parser : OhmParser;
import ohm.eval.backend : OhmBackend;
import ohm.eval.languagepass : OhmLanguagePass;
import ohm.eval.datastore : MemorizingVariableStore;
import ohm.eval.util : createSimpleModule, createSimpleFunction, addImport;


class OhmController : Controller
{
public:
	Settings settings;
	OhmParser frontend;
	OhmLanguagePass languagePass;
	OhmBackend backend;
	MemorizingVariableStore varStore;

	Pass[] debugVisitors;

protected:
	static struct ReplState {
		ir.Module mod;
		ir.Function replFunc;
		ir.Module transformed;
		State state;
	}
	ReplState[] mStack;
	@property ref ir.Module mModule() in { assert(mStack.length > 0); } body { return mStack[$-1].mod; }
	@property ref ir.Function mReplFunc() in { assert(mStack.length > 0); } body { return mStack[$-1].replFunc; }
	@property ref ir.Module mTransformed() in { assert(mStack.length > 0); } body { return mStack[$-1].transformed; }
	@property ref State mState() in { assert(mStack.length > 0); } body { return mStack[$-1].state; }

	string[] mIncludes;
	ir.Module[string] mModulesByName;
	ir.Module[string] mModulesByFile;

	LLVMModuleRef[string] mLLVMModules;

protected:
	this(Settings s, OhmParser f, OhmLanguagePass lp, OhmBackend b)
	{
		this.settings = s;
		this.frontend = f;
		this.languagePass = lp;
		this.backend = b;
		this.varStore = new MemorizingVariableStore();

		this.mIncludes = settings.stdIncludePaths;
		mIncludes ~= settings.includePaths;

		// LLVM setup
		LLVMLinkInMCJIT();
		this.loadModule(settings.stdFiles);
		this.loadLibrary(settings.libraryFiles);

		// create initial state
		this.mStack.length = 1;

		// AST setup
		this.mModule = createSimpleModule(["ohm"]);
		addImport(mModule, ["defaultsymbols"], false);
		addImport(mModule, ["object"], true);

		auto tlb = frontend.parseToplevel("
			extern(C) {
				void* __ohm_get_pointer(size_t id, const(char)* varName);
				void* __ohm_get_return_pointer(size_t id);
			}
		", Location());
		mModule.children.nodes ~= tlb.nodes;

		// main function which works as a scope and
		// will actually be called by the JIT
		this.mReplFunc = createSimpleFunction("__ohm_main");
		// the extyper will automatically set the correct return type
		mReplFunc.isAutoReturn = true;

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

	void push()
	{
		ReplState state;
		state.mod = mModule is null ? null : copy(mModule);
		state.replFunc = mReplFunc is null ? null : copy(mReplFunc);
		// mTransformed and mState get filled in later on
		state.transformed = null;
		state.state = null;
		mStack ~= state;
	}

	void pop()
	{
		if (mStack.length > 0) {
			auto state = mStack[$-1].state;
			if (state !is null) {
				state.close();
			}
		}
		// cut off the last element
		mStack.length = mStack.length-1;
		assert(mStack.length > 0, "pop called too many times");
	}

	void addTopLevel(ir.TopLevelBlock tlb)
	{
		if (tlb.nodes.length == 0)
			return;

		mModule.children.nodes ~= tlb.nodes;
	}

	void setStatements(ir.Node[] statements)
	{
		if (statements.length == 0) {
			mReplFunc._body.statements = [];
			return;
		}

		auto lastNode = statements[$-1];
		ir.Node[] otherNodes;
		otherNodes.length = statements.length-1;
		foreach (size_t i, statement; statements[0..$-1]) {
			otherNodes[i] = statement;
		}

		mReplFunc._body.statements = otherNodes;

		ir.Exp exp = null;
		if (auto expStmt = cast(ir.ExpStatement)lastNode) {
			if (!settings.ignoreAssignExpValue || !isAssign(expStmt.exp)) {
				exp = expStmt.exp;
			}
		} else {
			mReplFunc._body.statements ~= lastNode;
		}

		auto ret = new ir.ReturnStatement();
		ret.exp = exp;
		mReplFunc._body.statements ~= ret;
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
		foreach (rs; mStack) {
			if (rs.state !is null) {
				rs.state.close();
			}
		}

		frontend.close();
		languagePass.close();
		backend.close();

		settings = null;
		frontend = null;
		languagePass = null;
		backend = null;
	}

	VariableData run(size_t num) {
		mState = compile();
		return execute(mState, num);
	}

	void dumpModule()
	{
		if (mStack.length >= 2) {
			dumpModule(mStack[$-2].transformed);
		}
	}

	void dumpModule(ir.Module[] mods...)
	{
		foreach(pass; debugVisitors) {
			foreach(mod; mods) {
				if (mod is null)
					continue;
				pass.transform(mod);
			}
		}
	}

	void dumpIR()
	{
		if (mStack.length >= 2) {
			auto state = mStack[$-2].state;
			if (state !is null && state.mod !is null) {
				LLVMDumpModule(state.mod);
			}
		}
	}

	void loadModule(string[] paths...)
	{
		foreach (path; paths) {
			path = buildNormalizedPath(path);
			mLLVMModules[path] = .loadModule(LLVMContextCreate(), path);
		}
	}

	void loadLibrary(string[] libs...)
	{
		auto paths = "." ~ settings.libraryPaths;
		foreach (lib; libs) {
			bool success = false;
			for (size_t i = 0; i < paths.length && !success; i++) {
				auto libPath = buildNormalizedPath(paths[i], lib);
				success = LLVMLoadLibraryPermanently(toStringz(libPath)) == 0;
				if (!success) {
					try {
						loadModule(libPath);
					} catch (CompilerError e) {
						continue;
					}

					success = true;
				}
			}

			if (!success) {
				throw new CompilerError(format("Unable to load library '%s'.", lib));
			}
		}
	}

protected:
	State compile() {
		// make copies so wen can reuse the AST later on
		mTransformed = copy(mModule);
		auto copiedREPLFunc = copy(mReplFunc);
		mTransformed.children.nodes ~= copiedREPLFunc;

		ir.Module[] mods = [mTransformed];

		bool debugPassesRun = false;
		void debugPasses(ir.Module[] mods)
		{
			if (!debugPassesRun && settings.internalDebug) {
				debugPassesRun = true;
				dumpModule(mods);
			}
		}
		scope(failure) debugPasses([mTransformed]);

		// reset leftover state
		languagePass.reset();
		varStore.returnData = VariableData();

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

		debugPasses([mTransformed]);

		return backend.getCompiledModuleState(mTransformed);
	}

	VariableData execute(State state, size_t num)
	{
		string error;
		LLVMExecutionEngineRef ee = null;
		assert(LLVMCreateMCJITCompilerForModule(&ee, state.mod, null, 0, error) == 0, error);

		foreach (mod; mLLVMModules.values) {
			LLVMAddModule(ee, mod);
		}

		// workaround which calls ee->finalizeObjects, which makes
		// LLVMRunStaticConstructors not segfault
		LLVMDisposeGenericValue(LLVMRunFunction(ee, "vmain", []));
		LLVMRunStaticConstructors(ee);

		LLVMValueRef func;
		assert(LLVMFindFunction(ee, "__ohm_main", &func) == 0);
		LLVMDisposeGenericValue(LLVMRunFunction(ee, func, 0, null));

		varStore.safeResult(num);
		return varStore.returnData;
	}

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