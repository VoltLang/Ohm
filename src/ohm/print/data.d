module ohm.print.data;


import std.conv : to;
import std.string : format;
import core.stdc.ctype : isprint;

import volt.semantic.classify : size, alignment, isString;
import volt.interfaces : LanguagePass;
import volt.visitor.visitor;

import ohm.interfaces : VariableData;
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
	VariableData mEntry;
	void* mCurrent;

	void delegate(string) mSink;
	void delegate(string) mOldSink;

	int mIndent;
	string mIndentText;
	bool mInString;

	size_t mWritten;

public:
	this(LanguagePass lp, string indentText = "\t", void delegate(string) sink = null)
	{
		this.lp = lp;

		mIndentText = indentText;
		mSink = sink;
	}

	size_t format(VariableData entry, void delegate(string) sink = null)
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
		wf(*cast(void**)mCurrent);
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
		mInString = isString(array);

		wf(mInString ? "\"" : "[");
		for (size_t i = 0; i < arr.length; i++) {
			accept(array.base, this);

			if (i+1 < arr.length && !mInString) {
				wf(", ");
			}
		}
		wf(mInString ? "\"" : "]");

		mInString = false;
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
		wf(*cast(void**)mCurrent);
		mCurrent += size(lp, fn);
		return ContinueParent;
	}

	override Status enter(ir.DelegateType fn)
	{
		wf(*cast(void**)mCurrent);
		mCurrent += size(lp, fn);
		return ContinueParent;
	}

	override Status visit(ir.PrimitiveType it)
	{
		switch (it.type) with (ir.PrimitiveType.Kind) {
		case Void: break;
		case Bool: wf(*cast(bool*)mCurrent); break;
		case Char: wf(*cast(char*)mCurrent); break;
		case Wchar: wf(*cast(wchar*)mCurrent); break;
		case Dchar: wf(*cast(dchar*)mCurrent); break;
		case Byte: wf(*cast(byte*)mCurrent); break;
		case Ubyte: wf(*cast(ubyte*)mCurrent); break;
		case Short: wf(*cast(short*)mCurrent); break;
		case Ushort: wf(*cast(ushort*)mCurrent); break;
		case Int: wf(*cast(int*)mCurrent); break;
		case Uint: wf(*cast(uint*)mCurrent); break;
		case Long: wf(*cast(long*)mCurrent); break;
		case Ulong: wf(*cast(ulong*)mCurrent); break;
		case Float: wf(*cast(float*)mCurrent); break;
		case Double: wf(*cast(double*)mCurrent); break;
		case Real: wf(*cast(real*)mCurrent); break;
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

		mInString = false;
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

	void wf(void* ptr)
	{
		string s = ptr is null ? "null" : .format("0x%x", ptr);
		mSink(s);
	}

	void wf(bool b)
	{
		string s = .format("%s", b);
		mSink(s);
	}

	void wf(char c)
	{
		string s = escapeChar(c, `\x%02x`);
		mSink(s);
	}

	void wf(wchar c)
	{
		string s = escapeChar(c, `\u%04x`);
		mSink(s);
	}

	void wf(dchar c)
	{
		string s = escapeChar(c, `\U%08x`);
		mSink(s);
	}

	string escapeChar(dchar c, string fmt)
	{
		string s;

		switch(c) {
		case '\'': s = mInString ? `'` : `\'`; break;
		case '"': s = mInString ? `\"` : `"`; break;
		case '\\': s = `\\`; break;
		case '\0': s = `\0`; break;
		case '\a': s = `\a`; break;
		case '\b': s = `\b`; break;
		case '\f': s = `\f`; break;
		case '\n': s = `\n`; break;
		case '\r': s = `\r`; break;
		case '\t': s = `\t`; break;
		case '\v': s = `\v`; break;
		default:
			s = isprint(c) ? .format("%c", c) : .format(fmt, c);
			break;
		}

		return mInString ? s : .format("'%s'", s);
	}

	void wf(byte b)
	{
		string s = .format("%d", b);
		mSink(s);
	}

	void wf(ubyte b)
	{
		string s = .format("%d", b);
		mSink(s);
	}

	void wf(short sh)
	{
		string s = .format("%d", sh);
		mSink(s);
	}

	void wf(ushort sh)
	{
		string s = .format("%d", sh);
		mSink(s);
	}

	void wf(int i)
	{
		string s = .format("%d", i);
		mSink(s);
	}

	void wf(uint i)
	{
		string s = .format("%d", i);
		mSink(s);
	}

	void wf(long l)
	{
		string s = .format("%d", l);
		mSink(s);
	}

	void wf(ulong l)
	{
		string s = .format("%d", l);
		mSink(s);
	}

	void wf(float f)
	{
		string s = .format("%.13gf", f);
		mSink(s);
	}

	void wf(double d)
	{
		string s = .format("%.16g", d);
		mSink(s);
	}

	void wf(real r)
	{
		string s = .format("%.21g", r);
		mSink(s);
	}

	void wfln(string str){ wf(str); ln(); }

	void ln()
	{
		mSink("\n");
	}
}