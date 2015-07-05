module ohm.interactive;

import std.stdio : writeln, writefln;
import std.string;

import volt.token.location : Location;
import volt.llvm.interfaces : State;
import volt.exceptions : CompilerError;

import lib.editline.editline;

import ohm.volta.controller : OhmController;
import ohm.volta.backend : OhmBackend;
import ohm.volta.parser : OhmParser;
import ohm.settings : Settings;
import ohm.exceptions : ExitException, ContinueException;


interface Interactive {
public:
	void run();
}


class InteractiveConsole : Interactive {
public:
	Settings settings;
	OhmController controller;

	Location location;

	@property
	OhmParser parser() in { assert(controller !is null); } body { return controller.frontend; }

public:
	this(Settings settings)
	{
		this.settings = settings;

		this.location = Location("ohm", 0, 0, 0);

		this.controller = new OhmController(settings);

		read_history(settings.historyFile);
	}

	void run()
	{
		for (;; location.line++) {
			try {
				repl();
			} catch (ContinueException e) {
				continue;
			} catch (ExitException e) {
				break;
			} catch (CompilerError e) {
				if (settings.showStackTraces) {
					writeOther(e.toString());
				} else {
					writeOther(e.msg);
				}
			}
		}
	}

	void repl()
	{
		processInput();

		auto state = controller.compile();
		auto result = controller.execute(state);

		writeResult(result);
	}

protected:
	void processInput()
	{
		string line = getLine();

		saveLine(line);

		auto nodes = parser.parseStatements(line, location);
		controller.addStatement(nodes);
	}

	string getLine()
	{
		string line;

		do {
			writeln();
			line = readline("In [%d]: ".format(location.line + 1));
			if (line is null) throw new ExitException();
		} while (line.strip().length == 0);

		return line;
	}

	void writeResult(string line)
	{
		if (line.length > 0) {
			writefln("Out [%d]: %s", location.line + 1, line);
		}
	}

	void writeOther(string other)
	{
		writeln(other);
	}

	void saveLine(string line)
	{
		add_history(line);
		write_history(settings.historyFile);
	}
}