module ohm.io;


import std.stdio : writeln, stdout;
import std.string : format, strip;

import lib.editline.editline;

import ohm.interfaces : Reader, Writer;
import ohm.settings : Settings;
import ohm.exceptions : ExitException;
import ohm.util : balancedParens;


enum Parens {
	Open = ['(', '[', '{'],
	Close = [')', ']', '}'],
}


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

	string getInput(string prompt)
	{
		string input;

		do {
			writeln();
			input = getLine(prompt);
		} while (strip(input).length == 0);

		prompt = format(format("%%%ds", prompt.length), "...: ");
		while (!balancedParens(input, Parens.Open, Parens.Close)) {
			input = input ~ "\n" ~ getLine(prompt);
		}

		saveInput(input);

		return input;
	}

	void saveInput(string inp)
	{
		add_history(inp);
		write_history(settings.historyFile);
	}

protected:
	string getLine(string prompt)
	{
		auto line = readline(prompt);
		if (line is null) throw new ExitException();
		return line;
	}
}


class StdoutWriter : Writer
{
public:
	void writeResult(string output, string prompt)
	{
		if (output.length > 0) {
			writeln(prompt, output);
		}
	}

	void writeOther(string output)
	{
		writeln(output);
	}
}