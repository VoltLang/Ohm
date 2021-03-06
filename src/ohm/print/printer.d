module ohm.eval.printer;


import ir = volt.ir.ir;

import ohm.interfaces : Output, Printer;
import ohm.eval.datastore : VariableData;
import ohm.eval.driver : OhmDriver;
import ohm.print.type : TypeFormatter;
import ohm.print.data : DataFormatter;


class OhmPrinter : Printer
{
public:
	Output output;
	OhmDriver driver;
	TypeFormatter typeFormatter;
	DataFormatter dataFormatter;

protected:
	string mPrompt = null;

public:
	this(Output output, OhmDriver driver)
	{
		this.output = output;
		this.driver = driver;
		this.typeFormatter = new TypeFormatter("\t", &sink);
		this.dataFormatter = new DataFormatter(driver.languagePass, "\t", &sink);
	}

	void write(string output)
	{
		this.output.write(output);
	}

	void writeln(string output)
	{
		this.output.writeln(output);
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

	size_t print(VariableData entry, string prompt)
	{
		mPrompt = prompt;
		scope(exit) mPrompt = null;
		auto r = print(entry);
		if (r) {
			output.writeln("");
		}
		return r;
	}

	size_t print(VariableData entry)
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