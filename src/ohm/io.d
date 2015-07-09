module ohm.io;


import std.stdio : writeln, stdout;
import std.string : format, strip, toStringz;
import std.array : replicate;

import core.stdc.signal;

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

size_t indentNum = 0;
string indentStr = " ";
extern(C) int rlStartupHook()
{
	if (indentNum > 0) {
		rl_insert_text(toStringz(replicate(indentStr, indentNum)));
	}
	return 0;
}

private __gshared bool _signalGotCtrlC;
private extern(C) void ctrlCSignalHandler(int sig) nothrow @system @nogc
{
	if (sig == SIGINT) {
		// TODO windows
		_signalGotCtrlC = true;
	}
}

static this()
{
	signal(SIGINT, &ctrlCSignalHandler);
}

/*
 * This hook is required because it makes readline not wait
 * one character for rl_done but constantly check it.
 * It's dumb and undocumentated but it works ...
 *
 */
private __gshared bool _hookGotCtrlC;
extern(C) int rlEventHook()
{
	if (_signalGotCtrlC) {
		rl_done = 1;
		_signalGotCtrlC = false;
		_hookGotCtrlC = true;
	}
	return 0;
}

bool getResetHookGotCtrlC()
{
	if (_hookGotCtrlC) {
		_hookGotCtrlC = false;
		return true;
	}
	return false;
}


class StdinReadlineReader : Reader
{
public:
	Settings settings;

protected:
	string _history_file;

public:
	this(Settings settings)
	{
		this.settings = settings;
		// a stuipid workaround about some bug I simply
		// could not figure out ...
		this._history_file = settings.historyFile ~ "\0";

		read_history(this._history_file.ptr);
		rl_startup_hook = &rlStartupHook;
		rl_event_hook = &rlEventHook;
	}

	~this()
	{
		rl_event_hook = null;
		rl_startup_hook = null;
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
			input ~="\n" ~ getLine(prompt);
			balance = balancedParens(input, Parens.Open, Parens.Close);
		}

		saveInput(input);

		return input;
	}

	void saveInput(string inp)
	{
		add_history(inp);
		write_history(_history_file.ptr);
	}

protected:
	string getLine(string prompt)
	{
		auto line = readline(prompt);
		if (getResetHookGotCtrlC()) {
			writeln("Control-C");
			throw new ContinueException();
		}
		if (line is null) throw new ExitException();
		return line;
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