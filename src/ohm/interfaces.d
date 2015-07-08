module ohm.interfaces;



interface Interactive {
public:
	void run();
}


interface Reader
{
public:
	string getInput(size_t line);
}

interface Writer
{
public:
	void writeResult(string output, size_t line);

	void writeOther(string output, size_t line);
}


