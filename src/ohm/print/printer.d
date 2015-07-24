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

public:
	this(Output output, OhmController controller)
	{
		this.output = output;
		this.controller = controller;
		this.typeFormatter = new TypeFormatter("\t", &sink);
		this.dataFormatter = new DataFormatter(controller.languagePass, "\t", &sink);
	}

	void printType(ir.Type type)
	{
		typeFormatter.format(type);
	}

	void printData(ref StoreEntry entry)
	{
		dataFormatter.format(entry);
	}

protected:
	void sink(string s)
	{
		output.write(s);
	}
}