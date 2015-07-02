module lib.llvm.executionengine;

private import std.conv : to;
private import lib.llvm.core;
public import lib.llvm.c.ExecutionEngine;


alias LLVMCreateExecutionEngineForModule = lib.llvm.c.ExecutionEngine.LLVMCreateExecutionEngineForModule;
alias LLVMCreateMCJITCompilerForModule = lib.llvm.c.ExecutionEngine.LLVMCreateMCJITCompilerForModule;
alias LLVMRemoveModule = lib.llvm.c.ExecutionEngine.LLVMRemoveModule;


LLVMBool LLVMCreateExecutionEngineForModule(LLVMExecutionEngineRef *outEE, LLVMModuleRef mod, out string error)
{
	const(char)* str = null;
	auto ret = LLVMCreateExecutionEngineForModule(outEE, mod, &str);
	error = handleAndDisposeMessage(&str);

	return ret;
}


LLVMBool LLVMCreateMCJITCompilerForModule(LLVMExecutionEngineRef *outJIT, LLVMModuleRef mod, LLVMMCJITCompilerOptions options, out string error)
{
	const(char)* str = null;
	auto ret = LLVMCreateMCJITCompilerForModule(outJIT, mod, &options, options.sizeof, &str);
	error = handleAndDisposeMessage(&str);

	return ret;
}

LLVMBool LLVMCreateMCJITCompilerForModule(LLVMExecutionEngineRef *outJIT, LLVMModuleRef mod, LLVMMCJITCompilerOptions* options, size_t optionsSize, out string error)
{
	const(char)* str = null;
	auto ret = LLVMCreateMCJITCompilerForModule(outJIT, mod, options, optionsSize, &str);
	error = handleAndDisposeMessage(&str);

	return ret;
}

LLVMBool LLVMRemoveModule(LLVMExecutionEngineRef ee, LLVMModuleRef mod, LLVMModuleRef* outMod, out string error)
{
	const(char)* str = null;
	auto ret = LLVMRemoveModule(ee, mod, outMod, &str);
	error = handleAndDisposeMessage(&str);

	return ret;
}