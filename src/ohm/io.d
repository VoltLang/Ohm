module ohm.io;


import std.stdio : writeln, stdout;
import std.string : format, strip, toStringz;
import std.array : replicate;

import lib.readline.readline;
import lib.readline.history;

import ohm.interfaces : Reader, Writer;
import ohm.settings : Settings;
import ohm.exceptions : ExitException, ContinueException;
import ohm.util : balancedParens;


enum Parens {
	Open = ['(', '[', '{'],
	Close = [')', ']', '}'],
}

private size_t indentNum = 0;
private string indentStr = " ";
private extern(C) int indentSpaces()
{
	if (indentNum > 0) {
		rl_insert_text(toStringz(replicate(indentStr, indentNum)));
	}
	return 0;
}


class StdinReadlineReader : Reader
{
public:
	Settings settings;

protected:
	bool ctrlcPressed;

public:
	this(Settings settings)
	{
		this.settings = settings;

		read_history(settings.historyFile);

		rl_tty_unset_default_bindings(rl_get_keymap());
		rl_bind_key(CTRL('c'), &this.ctrlc);
		rl_startup_hook = &indentSpaces;
	}

	~this()
	{
		rl_startup_hook = null;
		rl_unbind_key(CTRL('c'));
		rl_tty_set_default_bindings(rl_get_keymap());
	}

	string getInput(string prompt)
	{
		string input;

		do {
			writeln();
			input = getLine(prompt);
		} while (strip(input).length == 0);

		scope(exit) resetIndent();

		prompt = format(format("%%%ds", prompt.length), "...: ");
		auto balance = balancedParens(input, Parens.Open, Parens.Close);
		while (balance > 0) {
			setIndent(balance*4);

			input = input ~ "\n" ~ getLine(prompt);

			balance = balancedParens(input, Parens.Open, Parens.Close);
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
		if (ctrlcPressed) {
			ctrlcPressed = false;
			throw new ContinueException();
		}
		if (line is null) throw new ExitException();
		return line;
	}

	void ctrlc(int a, int key)
	{
		writeln("\nControl-C");
		rl_done = 1;
		ctrlcPressed = true;
	}

	void setIndent(size_t num, string what = " ")
	{
		indentNum = num;
		indentStr = what;
	}

	void resetIndent()
	{
		indentNum = 0;
		indentStr = " ";
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