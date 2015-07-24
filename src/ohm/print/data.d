module ohm.print.data;


import std.conv : to;
import std.string : format;

import volt.semantic.classify : size, alignment;
import volt.interfaces : LanguagePass;
import volt.visitor.visitor;

import ohm.eval.datastore : StoreEntry;
import ohm.exceptions : FormatException;


struct VoltArray
{
	void* ptr;
	size_t length;
}

union VoltTreeStore {
	void* ptr;
	ulong unsigned;
	VoltArray array;
}

struct VoltTreeNode
{
	VoltTreeStore key;
	VoltTreeStore value;

	bool red;
	VoltTreeNode* parent;
	VoltTreeNode* left;
	VoltTreeNode* right;
}

// Basically only holds the root-node
struct VoltAA
{
	VoltTreeNode* root;
	size_t length;

	TypeInfo value;
	TypeInfo key;
}


class DataFormatter : NullVisitor
{
public:
	LanguagePass lp;

protected:
	StoreEntry mEntry;
	void* mCurrent;

	void delegate(string) mSink;
	void delegate(string) mOldSink;

	int mIndent;
	string mIndentText;

	size_t mWritten;

public:
	this(LanguagePass lp, string indentText = "\t", void delegate(string) sink = null)
	{
		this.lp = lp;

		mIndentText = indentText;
		mSink = sink;
	}

	size_t format(ref StoreEntry entry, void delegate(string) sink = null)
	{
		initSink(sink);
		scope(exit) restoreSink();

		mCurrent = entry.pointsToMemory ? entry.data.ptr : &entry.data;

		accept(entry.type, this);

		return mWritten;
	}

	override Status enter(ir.Class c)
	{
		wf(c.name);
		mCurrent += size(lp, c);
		return ContinueParent;
	}

	override Status enter(ir._Interface i)
	{
		wf(i.name);
		mCurrent += size(lp, i);
		return ContinueParent;
	}

	override Status enter(ir.Struct s)
	{
		auto oldCurrent = mCurrent;
		int offset = 0;

		ir.Variable[] nodes;
		foreach (node; s.members.nodes) {
			// If it's not a Variable, or not a field, it shouldn't take up space.
			auto asVar = cast(ir.Variable)node;
			if (asVar is null || asVar.storage != ir.Variable.Storage.Field) {
				continue;
			}
			nodes ~= asVar;
		}

		wf(s.name);
		wf("(");
		for (size_t i = 0; i < nodes.length; i++) {
			auto var = nodes[i];

			int a = cast(int)alignment(lp, var.type);
			int size = .size(lp, var.type);
			if (offset % a) {
				offset += (a - (offset % a));
			}

			mCurrent = oldCurrent + offset;
			accept(var.type, this);

			if (i+1 < nodes.length) {
				wf(", ");
			}

			offset += size;
		}
		wf(")");

		mCurrent = oldCurrent + size(lp, s);

		return ContinueParent;
	}

	override Status enter(ir.Union c)
	{
		wf(c.name);
		mCurrent += size(lp, c);
		return ContinueParent;
	}

	override Status enter(ir.PointerType pointer)
	{
		wf(to!string(*cast(void**)mCurrent));
		mCurrent += size(lp, pointer);
		return ContinueParent;
	}

	override Status enter(ir.ArrayType array)
	{
		//auto arr = *cast(void[]*)mCurrent;
		auto arr = *cast(VoltArray*) mCurrent;
		assert(VoltArray.sizeof == size(lp, array));

		auto oldCurrent = mCurrent;
		mCurrent = arr.ptr;

		wf("[");
		for (size_t i = 0; i < arr.length; i++) {
			accept(array.base, this);

			if (i+1 < arr.length) {
				wf(", ");
			}
		}
		wf("]");

		mCurrent = oldCurrent + size(lp, array);

		return ContinueParent;
	}

	override Status enter(ir.StaticArrayType array)
	{
		wf("[");
		for (size_t i = 0; i < array.length; i++) {
			accept(array.base, this);

			if (i+1 < array.length) {
				wf(", ");
			}
		}
		wf("]");

		return ContinueParent;
	}

	override Status enter(ir.AAType array)
	{
		auto vaa = *cast(VoltAA**) mCurrent;

		auto oldCurrent = mCurrent;

		wf("[");
		traverse(array, vaa.root);
		wf("]");

		mCurrent = oldCurrent + size(lp, array);

		return ContinueParent;
	}

	override Status enter(ir.FunctionType fn)
	{
		wf(to!string(*cast(void**)mCurrent));
		mCurrent += size(lp, fn);
		return ContinueParent;
	}

	override Status enter(ir.DelegateType fn)
	{
		wf(to!string(*cast(void**)mCurrent));
		mCurrent += size(lp, fn);
		return ContinueParent;
	}

	override Status visit(ir.PrimitiveType it)
	{
		switch (it.type) with (ir.PrimitiveType.Kind) {
		case Void: break;
		case Bool: wf(to!string(*cast(bool*) mCurrent)); break;
		case Char: wf(to!string(*cast(char*) mCurrent)); break;
		case Wchar: wf(to!string(*cast(wchar*) mCurrent)); break;
		case Dchar: wf(to!string(*cast(dchar*) mCurrent)); break;
		case Byte: wf(to!string(*cast(byte*) mCurrent)); break;
		case Ubyte: wf(to!string(*cast(ubyte*) mCurrent)); break;
		case Short: wf(to!string(*cast(short*) mCurrent)); break;
		case Ushort: wf(to!string(*cast(ushort*) mCurrent)); break;
		case Int: wf(to!string(*cast(int*) mCurrent)); break;
		case Uint: wf(to!string(*cast(uint*) mCurrent)); break;
		case Long: wf(to!string(*cast(long*) mCurrent)); break;
		case Ulong: wf(to!string(*cast(ulong*) mCurrent)); break;
		case Float: wf(to!string(*cast(float*) mCurrent)); break;
		case Double: wf(to!string(*cast(double*) mCurrent)); break;
		case Real: wf(to!string(*cast(real*) mCurrent)); break;
		default: assert(false);
		}

		mCurrent += size(lp, it);

		return ContinueParent;
	}

	override Status visit(ir.TypeReference tr)
	{
		accept(tr.type, this);
		return ContinueParent;
	}

	override Status visit(ir.NullType nt)
	{
		wf("null");
		mCurrent += size(lp, nt);
		return ContinueParent;
	}

protected:
	void initSink(void delegate(string) sink)
	{
		mOldSink = mSink;
		sink = sink is null ? mSink : sink;

		if (sink is null) {
			throw new FormatException("A sink is required.");
		}

		mWritten = 0;
		void wrappedSink(string s) {
			mWritten += s.length;
			sink(s);
		}
		mSink = &wrappedSink;
	}

	void restoreSink()
	{
		mSink = mOldSink;
		mOldSink = null;
	}

	void traverse(ir.AAType array, VoltTreeNode* node)
	{
		if (node is null)
			return;

		if (node.left !is null) {
			traverse(array, node.left);
			wf(", ");
		}

		visit(array.key, &node.key);
		wf(":");
		visit(array.value, &node.value);

		if (node.right !is null) {
			wf(", ");
			traverse(array, node.right);
		}
	}

	void visit(ir.Type type, VoltTreeStore* store)
	{
		mCurrent = store;
		if (size(lp, type) > VoltTreeStore.sizeof) {
			mCurrent = store.ptr;
		}

		accept(type, this);
	}

	void internalPrintBlock(ir.BlockStatement bs)
	{
		foreach (statement; bs.statements) {
			accept(statement, this);
			if (statement.nodeType == ir.NodeType.Variable) {
				ln();
			}
		}
	}

	void wf(ir.QualifiedName qn)
	{
		if (qn.leadingDot)
			wf(".");
		wf(qn.identifiers[0].value);

		foreach(id; qn.identifiers[1 .. $]) {
			wf(".");
			wf(id.value);
		}
	}

	void twf(string[] strings...)
	{
		for (int i; i < mIndent; i++) {
			mSink(mIndentText);
		}
		foreach (s; strings) {
			mSink(s);
		}
	}

	void twfln(string[] strings...)
	{
		foreach (s; strings) {
			twf(s);
			ln();
		}
	}

	void wf(string[] strings...)
	{
		foreach (s; strings) {
			mSink(s);
		}
	}

	void wf(int i)
	{
		string s = .format("%s", i);
		mSink(s);
	}

	void wf(long l)
	{
		string s = .format("%s", l);
		mSink(s);
	}

	void wf(size_t i)
	{
		string s = .format("%s", i);
		mSink(s);
	}

	void wfln(string str){ wf(str); ln(); }

	void ln()
	{
		mSink("\n");
	}
}