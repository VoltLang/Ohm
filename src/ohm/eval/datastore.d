module ohm.eval.datastore;


import std.conv : to;
import std.stdio : stderr;
import std.string : format;
import std.algorithm : canFind, countUntil, remove;

import ir = volt.ir.ir;
import volt.semantic.classify : size;

import ohm.interfaces : VariableData;

import lib.llvm.c.Support : LLVMAddSymbol;


private {
	__gshared VariableStore[size_t] _stores;

	extern(C) void* ohm_get_pointer(size_t id, const(char)* varName)
	{
		try {
			return _stores[id].getPointer(to!string(varName));
		} catch (Throwable t) {
			stderr.writeln("Ohm Get Pointer ERROR: ", t);
		}
		return null;
	}

	extern(C) void* ohm_get_return_pointer(size_t id)
	{
		try {
			return _stores[id].getReturnPointer();
		} catch (Throwable t) {
			stderr.writeln("Ohm Get Return Pointer ERROR: ", t);
		}
		return null;
	}
}

static this()
{
	LLVMAddSymbol("__ohm_get_pointer", cast(void*)&ohm_get_pointer);
	LLVMAddSymbol("__ohm_get_return_pointer", cast(void*)&ohm_get_return_pointer);
}


class VariableStore
{
private:
	static __gshared size_t _last_id = 0;
	static size_t getNextId()
	{
		return ++_last_id;
	}

public:
	VariableData[string] data;
	VariableData returnData;

	string[] requireInit;

private:
	size_t _id;

public:
	this()
	{
		this._id = getNextId();
		_stores[this.id] = this;
	}

	@property final size_t id()
	{
		return _id;
	}

	void initLater(string name)
	{
		if (!canFind(requireInit, name)) {
			requireInit ~= name;
		}
	}

	bool willInitLater(string name)
	{
		return canFind(requireInit, name);
	}

	void init(string name, ir.Type type, size_t size)
	{
		VariableData entry;
		init(entry, name, type, size);
		// maybe check if this name already exists and fail
		data[name] = entry;

		auto index = countUntil(requireInit, name);
		if (index >= 0) {
			requireInit = remove(requireInit, index);
		}
	}

	void* getPointer(string name)
	{
		return getPointer(data[name]);
	}

	ref VariableData get(string name)
	{
		return data[name];
	}

	bool has(string name)
	{
		return (name in data) !is null;
	}

	VariableData[] values()
	{
		return data.values;
	}

	void initReturn(ir.Type type, size_t size)
	{
		init(returnData, "return", type, size);
	}

	void* getReturnPointer()
	{
		return getPointer(returnData);
	}

protected:
	void init(out VariableData entry, string name, ir.Type type, size_t size)
	{
		entry.name = name;

		entry.type = type;
		entry.size = size;

		entry.data.unsigned = 0;
		entry.pointsToMemory = false;

		if (size > entry.data.sizeof) {
			entry.data.ptr = (new ubyte[size]).ptr;
			entry.pointsToMemory = true;
		}
	}

	void* getPointer(ref VariableData entry)
	{
		if (entry.pointsToMemory) {
			return entry.data.ptr;
		}
		return &(entry.data);
	}
}
