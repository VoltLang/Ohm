module ohm.interactive;

import std.string : format;

import volt.token.location : Location;
import volt.llvm.interfaces : State;
import volt.exceptions : CompilerError;

import ohm.interfaces : Interactive, Reader, Writer;
import ohm.eval.controller : OhmController;
import ohm.eval.backend : OhmBackend;
import ohm.eval.parser : OhmParser;
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
		for (;;) {
			try {
				repl();
			} catch (ContinueException e) {
				continue;
			} catch (ExitException e) {
				break;
			} catch (CompilerError e) {
				writer.writeOther(
					settings.showStackTraces ? e.toString() : e.msg
				);
			}

			location.line++;
		}
	}

	void repl()
	{
		processInput();

		auto state = controller.compile();
		auto result = controller.execute(state);

		writer.writeResult(result.toString(), outputPrompt);
	}

protected:
	void processInput()
	{
		string input = reader.getInput(inputPrompt);

		// append ; automatically, the parser generates Empty* nodes for it,
		// but they are ignored later on, so this is fine.
		auto nodes = parser.parseStatements(input ~ ";", location);
		if (nodes.length == 0) {
			throw new ContinueException();
		}

		controller.addStatement(nodes);
	}

	@property string inputPrompt()
	{
		return format("In [%d]: ", location.line + 1);
	}

	@property string outputPrompt()
	{
		return format("Out[%d]: ", location.line + 1);
	}
}