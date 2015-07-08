module ohm.interactive;

import std.stdio : writeln, writefln;

import volt.token.location : Location;
import volt.llvm.interfaces : State;
import volt.exceptions : CompilerError;

import ohm.interfaces : Interactive, Reader, Writer;
import ohm.volta.controller : OhmController;
import ohm.volta.backend : OhmBackend;
import ohm.volta.parser : OhmParser;
import ohm.settings : Settings;
import ohm.exceptions : ExitException, ContinueException;


class InteractiveConsole : Interactive {
public:
	Settings settings;
	OhmController controller;
	Reader reader;
	Writer writer;

	Location location;

	@property
	OhmParser parser() in { assert(controller !is null); } body { return controller.frontend; }

public:
	this(Settings settings, Reader reader, Writer writer)
	{
		this.settings = settings;
		this.reader = reader;
		this.writer = writer;

		this.location = Location("ohm", 0, 0, 0);
		this.controller = new OhmController(settings);
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
				writer.writeOther(
					settings.showStackTraces ? e.toString() : e.msg,
					location.line + 1
				);
			}
		}
	}

	void repl()
	{
		processInput();

		auto state = controller.compile();
		auto result = controller.execute(state);

		writer.writeResult(result, location.line + 1);
	}

protected:
	void processInput()
	{
		string input = reader.getInput(location.line + 1);

		// append ; automatically, the parser generates Empty* nodes for it,
		// but they are ignored later on, so this is fine.
		auto nodes = parser.parseStatements(input ~ ";", location);
		if (nodes.length == 0) {
			throw new ContinueException();
		}

		controller.addStatement(nodes);
	}
}