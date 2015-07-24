module ohm.data.type;


import std.cstream : dout;

import ir = volt.ir.ir;
import volt.visitor.visitor : accept;
import volt.visitor.prettyprinter : PrettyPrinter;

import ohm.exceptions : FormatException;


class TypeFormatter : PrettyPrinter
{
protected:
	void delegate(string) mOldSink = null;

	size_t mWritten;

public:
	this(string indentText = "\t", void delegate(string) sink = null)
	{
		super(indentText, sink);
	}

	size_t format(ir.Type type, void delegate(string) sink = null)
	{
		if (type is null) {
			throw new FormatException("type is null.");
		}

		initSink(sink);
		scope(exit) restoreSink();

		accept(type, this);

		return mWritten;
	}

protected:
	void initSink(void delegate(string) sink = null)
	{
		mStream = dout;
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
		mStream = null;
		mSink = mOldSink;
		mOldSink = null;
	}
}