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
	size_t print(ir.Type type, string prompt);
	size_t print(ir.Type type);

	size_t print(ref StoreEntry entry, string prompt);
	size_t print(ref StoreEntry entry);
}
