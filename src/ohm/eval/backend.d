module ohm.eval.backend;

import std.stdio : stdout, stderr;

import ir = volt.ir.ir;
import lib.llvm.analysis;
import lib.llvm.core;
import lib.llvm.executionengine;
import volt.errors : panic;
import volt.interfaces : LanguagePass;
import volt.llvm.backend : loadModule, LlvmBackend;
import volt.llvm.state : VoltState;
import volt.llvm.interfaces : State;



class OhmBackend : LlvmBackend
{
	this(LanguagePass lp) {
		super(lp);
	}

	State getCompiledModuleState(ir.Module m)
	{
		auto state = new VoltState(lp, m);
		auto mod = state.mod;

		if (mDump)
			stdout.writefln("Compiling module");

		try {
			state.compile(m);
		} catch (Throwable t) {
			if (mDump) {
				stdout.writefln("Caught \"%s\" dumping module:", t.classinfo.name);
				LLVMDumpModule(mod);
			}
			throw t;
		}

		if (mDump) {
			LLVMDumpModule(state.mod);
		}

		string result;
		auto failed = LLVMVerifyModule(mod, result);
		if (failed) {
			stderr.writefln("%s", result);
			throw panic("Module verification failed.");
		}

		return state;
	}
}
