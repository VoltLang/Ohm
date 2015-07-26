module ohm.read.reader;


import std.string : format, strip;
import std.uni : isWhite;

import ir = volt.ir.ir;
import volt.token.location : Location;
import volt.exceptions : CompilerError;

import ohm.interfaces : Input, Reader, CommandCallback;
import ohm.exceptions : ExitException, ContinueException;
import ohm.eval.controller : OhmController;
import ohm.read.parser : OhmParser;
import ohm.read.util : Balance, balancedParens;


class OhmReader : Reader
{
public:
	Input input;
	OhmController controller;

	@property
	OhmParser parser() in { assert(controller !is null); } body { return controller.frontend; }

protected:
	CommandCallback[string] mCommands;

public:
	this(Input input, OhmController controller)
	{
		this.input = input;
		this.controller = controller;
	}

	void read(Location location, string prompt, bool processCommands = true)
	{
		string source = input.getInput(prompt, &needsToReadMore);
		process(location, source, processCommands);
	}

	void process(Location location, string source, bool processCommands = true)
	{
		if (processCommands && !this.processCommands(location, source)) {
			throw new ContinueException();
		}

		ir.TopLevelBlock tlb;
		ir.Node[] statements;

		// the parser will eat/ignore additional semicolons
		parser.parseTopLevelsOrStatements(source ~ ";", location, tlb, statements);

		controller.addTopLevel(tlb);
		controller.setStatements(statements);

		// don't compile if we did nothing but (re)set the statements
		if (statements.length == 0 && tlb.nodes.length == 0) {
			throw new ContinueException();
		}
	}

	void setCommand(string command, CommandCallback callback)
	{
		if (callback is null) {
			mCommands.remove(command);
		} else {
			mCommands[command] = callback;
		}
	}

	CommandCallback getCommand(string command)
	{
		if (auto callback = command in mCommands) {
			return *callback;
		}
		return null;
	}

protected:
	int needsToReadMore(string soFar)
	{
		int indentLevel;
		auto balance = balancedParens(soFar, indentLevel);

		// return indentation level if not balanced, -1 otherwise
		return balance == Balance.BALANCED ? -1 : indentLevel;
	}

	bool processCommands(ref Location location, ref string source)
	{
		auto origSource = source;
		auto origLocation = location;
		string command = null;
		source = strip(source);
		foreach (size_t i, c; source) {
			if (isWhite(c)) {
				command = source[0..i];
				i = source.length >= i ? i+1 : i;
				source = source[i..$];
				location.column = i;
				break;
			}
		}

		// swap command and source, the source might be the command
		if (command == null) {
			command = source;
			source = null;
		}

		if (auto commandCallback = getCommand(command)) {
			return commandCallback(command, location, source);
		}

		// reset, if there was no command
		source = origSource;
		location = origLocation;
		return true;
	}
}