module ohm.eval.datastore;


import std.conv : to;
import std.stdio : stderr;

import ir = volt.ir.ir;

import lib.llvm.c.Support : LLVMAddSymbol;


private {
	__gshared VariableStore[size_t] _stores;

	extern(C) void ohm_store(size_t id, const(char)* varName, int value)
	{
		try {
			_stores[id].setInt(to!string(varName), value);
		} catch (Throwable t) { // LLVM doesn't like D exceptions from within JITed functions
			stderr.writeln("Ohm Store ERROR: ", t);
		}
	}

	extern(C) int ohm_load(size_t id, const(char)* varName)
	{
		try {
			return _stores[id].getInt(to!string(varName));
		} catch (Throwable t) {
			stderr.writeln("Ohm Load ERROR: ", t);
		}
		return 0;
	}
}

static this()
{
	LLVMAddSymbol("__ohm_store", cast(void*)&ohm_store);
	LLVMAddSymbol("__ohm_load", cast(void*)&ohm_load);
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
		ir.Type type;

		union Data {
			void* ptr;
			ulong unsigned;
			void[] array;
		}

		Data data;
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

	// just a really simple implementation for now
	void setInt(string name, int value)
	{
		StoreEntry entry;
		entry.data.unsigned = cast(ulong)value;
		data[name] = entry;
	}

	int getInt(string name)
	{
		return cast(int)data[name].data.unsigned;
	}
}