module ohm.interfaces;


import volt.token.location : Location;



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

	void writeOther(string output);
}


interface Reader
{
public:
	void processInput(Location location, string prompt);
}
