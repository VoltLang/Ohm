module ohm.io;


import std.stdio : writeln, writefln;
import std.string : format, strip;

import lib.editline.editline;

import ohm.interfaces : Reader, Writer;
import ohm.settings : Settings;
import ohm.exceptions : ExitException;


class StdinReadlineReader : Reader
{
public:
	Settings settings;

public:
	this(Settings settings)
	{
		this.settings = settings;

		read_history(settings.historyFile);
	}

	string getInput(size_t line)
	{
		string input;

		do {
			writeln();
			input = readline("In [%d]: ".format(line));
			if (input is null) throw new ExitException();
		} while (strip(input).length == 0);

		return input;
	}

	void saveInput(string inp)
	{
		add_history(inp);
		write_history(settings.historyFile);
	}
}


class StdoutWriter : Writer
{
public:
	void writeResult(string output, size_t line)
	{
		if (output.length > 0) {
			writefln("Out [%d]: %s", line, output);
		}
	}

	void writeOther(string output, size_t line)
	{
		writeln(output);
	}
}