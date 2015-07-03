module ohm.interactive;

import std.stdio : File, stdin, stdout;
import std.string;

import volt.interfaces : Settings;
import volt.token.location : Location;
import volt.llvm.interfaces : State;

import lib.llvm.executionengine;
import lib.llvm.analysis;
import lib.llvm.core;

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

protected:
	File input;
	File output;

public:
	this(Settings settings, File input, File output)
	{
		this.settings = settings;
		this.input = input;
		this.output = output;

		this.location.filename = "ohm";
		this.location.line = 1;

		this.controller = new OhmController(settings);

		LLVMLinkInInterpreter();
		LLVMLinkInMCJIT();
	}

	void run()
	{
		string line;
		while (!input.eof()) {
			printInputPrompt();
			string result = processInput();

			if (result && result.length > 0) {
				printOutputPrompt();
				output.write(result);
				output.write("\n");
			}

			++location.line;
		}
	}

protected:
	string processInput()
	{
		string line = input.readln();
		if (line is null) {
			return line;
		}

		if (line.strip().length > 0) {
			controller.addStatement(line, location);
		}
		auto state = controller.compile();
		scope(exit) state.close();

		string error;
		LLVMExecutionEngineRef ee = null;
		assert(LLVMCreateMCJITCompilerForModule(&ee, state.mod, null, 0, error) == 0, error);
		LLVMValueRef func;
		assert(LLVMFindFunction(ee, "__ohm_main", &func) == 0);
		LLVMGenericValueRef val = LLVMRunFunction(ee, func, 0, null);
		scope(exit) LLVMDisposeGenericValue(val);

		return to!string(LLVMGenericValueToInt(val, false));
	}

	void printInputPrompt()
	{
		output.writef("\nIn [%d]: ", location.line);
	}

	void printOutputPrompt()
	{
		output.writef("Out [%d]: ", location.line);
	}
}