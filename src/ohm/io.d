module ohm.io;


import std.stdio : File, stdout, writeln;
import std.string : format, strip, toStringz;
import std.array : replicate;

import core.stdc.signal;
import core.stdc.time;

import lib.readline.readline;
import lib.readline.history;

import ohm.interfaces : Input, Output;
import ohm.settings : Settings;
import ohm.exceptions : ExitException, ContinueException;


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
private __gshared time_t _lastCtrlC = 0;
private extern(C) void ctrlCSignalHandler(int sig) nothrow @system @nogc
{
	// TODO windows
	if (sig == SIGINT) {
		auto now = time(null);

		// reraise the signal if in the last 2 seconds Ctrl+C got pressed more than once
		// and it was not during readline input (which resets _signalGotCtrlC).
		if (difftime(now, _lastCtrlC) < 2 && _signalGotCtrlC) {
			signal(sig, SIG_DFL);
			raise(sig);
		}
		_lastCtrlC = now;

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


class StdinReadlineInput : Input
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

	string getInput(string prompt, int delegate(string) readMore = null)
	{
		string input;

		do {
			writeln();
			input = getLine(prompt);
		} while (strip(input).length == 0);

		if (readMore !is null) {
			scope(exit) resetIndent();

			prompt = format(format("%%%ds", prompt.length), "...: ");

			// read data as long as readMore returns a negative integer
			// the returned integer >= resembles the indentation level
			for (auto indent = readMore(input); indent >= 0; indent = readMore(input)) {
				setIndent(indent, "    ");
				input ~= "\n" ~ getLine(prompt);
			}
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


class StdoutOutput : Output
{
public:
	File file;

public:
	this()
	{
		this.file = stdout;
	}

	this(File file)
	{
		this.file = file;
	}

	void write(string output)
	{
		file.write(output);
	}

	void writeln(string output)
	{
		file.writeln(output);
	}
}