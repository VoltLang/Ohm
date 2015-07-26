module ohm.interfaces;


import ir = volt.ir.ir;
import volt.token.location : Location;


struct VariableData
{
public:
	string name;

	ir.Type type;
	size_t size;

	union Data {
		void* ptr;
		ulong unsigned;
		real floating;
		void[] array;
	}

	Data data;
	bool pointsToMemory;
}


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


alias CommandCallback = bool delegate(string command, ref Location location, ref string source);

interface Reader
{
public:
	void read(Location location, string prompt, bool processCommands = true);
	void process(Location location, string source, bool processCommands = true);

	void setCommand(string command, CommandCallback callback);
	CommandCallback getCommand(string command);
}

interface Printer : Output
{
public:
	size_t print(ir.Type type, string prompt);
	size_t print(ir.Type type);

	size_t print(VariableData entry, string prompt);
	size_t print(VariableData entry);
}
