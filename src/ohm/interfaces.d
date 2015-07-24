module ohm.interfaces;


import ir = volt.ir.ir;
import volt.token.location : Location;

import ohm.eval.datastore : StoreEntry;



interface Interactive {
public:
	void run();
}


interface Input
{
public:
	string getInput(string prompt, int delegate(string) readMore = null);
}

interface Output
{
public:
	void writeResult(string output, string prompt);

	void write(string output);
	void writeln(string output);
}


interface Reader
{
public:
	void processInput(Location location, string prompt);
}

interface Printer
{
public:
	void printType(ir.Type type);

	void printData(ref StoreEntry entry);
}
