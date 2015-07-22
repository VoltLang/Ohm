module ohm.eval.datastore;


import std.conv : to;
import std.stdio : stderr;
import std.string : format;

import ir = volt.ir.ir;

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


struct StoreEntry
{
public:
	string name;
	ir.Type type;

	union Data {
		void* ptr;
		ulong unsigned;
		real floating;
		void[] array;
	}

	Data data;
	bool pointsToMemory;

public:
	string toString()
	{
		if (type is null)
			return null;

		auto asPrim = cast(ir.PrimitiveType) type;
		if (asPrim !is null && asPrim.type == ir.PrimitiveType.Kind.Void)
			return null;

		// TODO ir.Type + data -> string
		// TODO use pointsToMemory
		return format("<%s>: %s", type, cast(long)data.unsigned);
	}
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
	StoreEntry[string] data;
	StoreEntry returnData;

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

	void init(string name, ir.Type type)
	{
		StoreEntry entry;
		init(entry, name, type);
		// maybe check if this name already exists and fail
		data[name] = entry;
	}

	void* getPointer(string name)
	{
		return getPointer(data[name]);
	}

	ref StoreEntry get(string name)
	{
		return data[name];
	}

	bool has(string name)
	{
		return (name in data) !is null;
	}

	StoreEntry[] values()
	{
		return data.values;
	}

	void initReturn(ir.Type type)
	{
		init(returnData, "return", type);
	}

	void* getReturnPointer()
	{
		return getPointer(returnData);
	}

protected:
	void init(out StoreEntry entry, string name, ir.Type type)
	{
		entry.name = name;
		entry.type = type;

		entry.data.unsigned = 0;

		// TODO allocate memory if necessary,
		// store the memory region in data.ptr
		entry.pointsToMemory = false;
	}

	void* getPointer(ref StoreEntry entry)
	{
		if (entry.pointsToMemory) {
			return entry.data.ptr;
		}
		return &(entry.data);
	}
}
