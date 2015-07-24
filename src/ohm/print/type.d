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

public:
	this(string indentText = "\t", void delegate(string) sink = null)
	{
		super(indentText, sink);
	}

	void format(ir.Type type, void delegate(string) sink = null)
	{
		if (type is null) {
			throw new FormatException("type is null.");
		}

		initSink(sink);
		scope(exit) restoreSink();

		accept(type, this);
	}

protected:
	void initSink(void delegate(string) sink = null)
	{
		mStream = dout;
		mOldSink = mSink;
		mSink = sink is null ? mSink : sink;

		if (mSink is null) {
			throw new FormatException("A sink is required.");
		}
	}

	void restoreSink()
	{
		mStream = null;
		mSink = mOldSink;
		mOldSink = null;
	}
}