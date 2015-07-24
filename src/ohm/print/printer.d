module ohm.eval.printer;


import ir = volt.ir.ir;

import ohm.interfaces : Output, Printer;
import ohm.eval.datastore : StoreEntry;
import ohm.eval.controller : OhmController;
import ohm.print.type : TypeFormatter;
import ohm.print.data : DataFormatter;


class OhmPrinter : Printer
{
public:
	Output output;
	OhmController controller;
	TypeFormatter typeFormatter;
	DataFormatter dataFormatter;

protected:
	string mPrompt = null;

public:
	this(Output output, OhmController controller)
	{
		this.output = output;
		this.controller = controller;
		this.typeFormatter = new TypeFormatter("\t", &sink);
		this.dataFormatter = new DataFormatter(controller.languagePass, "\t", &sink);
	}

	size_t print(ir.Type type, string prompt)
	{
		mPrompt = prompt;
		scope(exit) mPrompt = null;
		auto r = print(type);
		if (r) {
			output.writeln("");
		}
		return r;
	}

	size_t print(ir.Type type)
	{
		return typeFormatter.format(type);
	}

	size_t print(ref StoreEntry entry, string prompt)
	{
		mPrompt = prompt;
		scope(exit) mPrompt = null;
		auto r = print(entry);
		if (r) {
			output.writeln("");
		}
		return r;
	}

	size_t print(ref StoreEntry entry)
	{
		return dataFormatter.format(entry);
	}

protected:
	void sink(string s)
	{
		if (mPrompt.length > 0) {
			output.write(mPrompt);
			mPrompt = null;
		}

		output.write(s);
	}
}