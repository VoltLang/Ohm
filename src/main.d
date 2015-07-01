import std.stdio;

import std.conv : to;

import ir = volt.ir.ir;
import volt.interfaces : Controller, Settings, Platform, Arch;
import volt.token.location : Location;
import volt.parser.parser : Parser;
import volt.llvm.interfaces : State;

import lib.llvm.executionengine;
import lib.llvm.analysis;
import lib.llvm.core;

import ohm.volta.controller : OhmController;


void main()
{
	Settings settings = new Settings(".");
	setDefault(settings);
	settings.internalDebug = true;

	OhmController oc = new OhmController(settings);
	scope(exit) oc.close();

	LLVMLinkInInterpreter();
	LLVMLinkInMCJIT();

	Location loc;
	loc.filename = "first";
	// important, changing global to local here seems to trigger a llvm bug
	oc.addTopLevel("global int x = 3;", loc);
	loc.filename = "second";
	oc.addTopLevel("extern(C) int printf(const(char)*, ...);", loc);
	loc.filename = "third";
	oc.addTopLevel("extern(C) int test() { printf(\"I am foo\\n\"); int y = 3; printf(\"x:%d y:%d\n\", x, y); return y+39;}", loc);

	State state = oc.compile();
	scope (exit)
		state.close();

	char *error = null;
	LLVMExecutionEngineRef ee = null;

	//assert(LLVMCreateExecutionEngineForModule(&ee, state.mod, &error) == 0);

	// on a LLVMGetFunctionAddress or LLVMRunFunction call MCJit hangs
	// LLVMMCJITCompilerOptions options;
	// options.MCJMM = null;
	// LLVMInitializeMCJITCompilerOptions(&options, options.sizeof);
	//assert(LLVMCreateMCJITCompilerForModule(&ee, state.mod, &options, options.sizeof, &error) == 0);
	assert(LLVMCreateMCJITCompilerForModule(&ee, state.mod, null, 0, null) == 0);

	if (error)
		writefln("Error: %s", to!string(error));

	writeln("==============  JIT   ==============");
	LLVMValueRef func;
	assert(LLVMFindFunction(ee, "test", &func) == 0);
	writefln("Func: %s, Status: %s", func, LLVMVerifyFunction(func, LLVMVerifierFailureAction.ReturnStatus));
	writefln("Addr: %s", LLVMGetFunctionAddress(ee, "test"));

	writeln("==============  EXEC  ==============");
	// alternative:
	// (cast(int function())(cast(void*)LLVMGetFunctionAddress(ee, "test")))();
	LLVMGenericValueRef val = LLVMRunFunction(ee, func, 0, null);
	scope (exit)
		LLVMDisposeGenericValue(val);
	writeln("==============  DONE  ==============");
	writefln("Function returned: %d", LLVMGenericValueToInt(val, false));
}

void setDefault(Settings settings)
{
	// Only MinGW is supported.
	version (Windows) {
		settings.platform = Platform.MinGW;
	} else version (linux) {
		settings.platform = Platform.Linux;
	} else version (OSX) {
		settings.platform = Platform.OSX;
	} else {
		static assert(false);
	}

	version (X86) {
		settings.arch = Arch.X86;
	} else version (X86_64) {
		settings.arch = Arch.X86_64;
	} else {
		static assert(false);
	}
}
