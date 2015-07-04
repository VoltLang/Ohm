module ohm.interactive;

import std.stdio : writeln, writefln;
import std.string;

import volt.interfaces : Settings;
import volt.token.location : Location;
import volt.llvm.interfaces : State;
import volt.llvm.backend : loadModule;

import lib.llvm.executionengine;
import lib.llvm.analysis;
import lib.llvm.core;
import lib.llvm.support;
import lib.editline.editline;

import ohm.volta.controller : OhmController;
import ohm.volta.backend : OhmBackend;


interface Interactive {
public:
	void run();
}


class InteractiveConsole : Interactive {
public:
	Settings settings;
	OhmController controller;

	Location location;

	// TODO move into settings
	string history = ".ohm.history";

public:
	this(Settings settings)
	{
		this.settings = settings;

		this.location.filename = "ohm";
		this.location.line = 1;

		this.controller = new OhmController(settings);

		LLVMLinkInInterpreter();
		LLVMLinkInMCJIT();

		foreach (lib; settings.libraryFiles) {
			LLVMLoadLibraryPermanently(toStringz(lib));
		}

		read_history(this.history);
	}

	void run()
	{
		while (true) {
			string line = getLine();
			if (line.length == 0) break;
			if (line.strip().length == 0) continue;

			saveLine(line);

			string result = processInput(line);
			if (result && result.length > 0) {
				writeLine(result);
			}

			++location.line;
		}
	}

protected:
	string processInput(string line)
	{
		if (line.strip().length > 0) {
			controller.addStatement(line, location);
		}
		auto state = controller.compile();
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

		return to!string(LLVMGenericValueToInt(val, false));
	}

	string getLine()
	{
		writeln();
		return readline("In [%d]: ".format(location.line));
	}

	void writeLine(string line)
	{
		writefln("Out [%d]: %s", location.line, line);
	}

	void saveLine(string line)
	{
		add_history(line);
		write_history(this.history);
	}
}