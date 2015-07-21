module ohm.eval.datastore;


import std.conv : to;
import std.stdio : stderr;

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
}

static this()
{
	LLVMAddSymbol("__ohm_get_pointer", cast(void*)&ohm_get_pointer);
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
	static struct StoreEntry
	{
	public:
		string name;
		ir.Type type;

		union Data {
			void* ptr;
			ulong unsigned;
			void[] array;
		}

		Data data;
		bool pointsToMemory;
	}

protected:
	StoreEntry[string] data;

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
		entry.name = name;
		entry.type = type;

		// TODO allocate memory if necessary,
		// store the memory region in data.ptr
		entry.pointsToMemory = false;

		// maybe check if this name already exists and fail
		data[name] = entry;
	}

	void* getPointer(string name)
	{
		auto entry = &data[name];
		assert(entry !is null);

		if (entry.pointsToMemory) {
			return entry.data.ptr;
		}
		return &(entry.data);
	}

	ir.Type getType(string name)
	{
		return data[name].type;
	}

	bool has(string name)
	{
		return (name in data) !is null;
	}

	StoreEntry[] values()
	{
		return data.values;
	}
}