module ohm.interfaces;



interface Interactive {
public:
	void run();
}


interface Reader
{
public:
	string getInput(string prompt);
}

interface Writer
{
public:
	void writeResult(string output, string prompt);

	void writeOther(string output);
}


