module ohm.interactive;

import std.string : format;

import volt.token.location : Location;
import volt.llvm.interfaces : State;
import volt.exceptions : CompilerError;

import ohm.interfaces : Interactive, Input, Output, Reader;
import ohm.eval.controller : OhmController;
import ohm.eval.backend : OhmBackend;
import ohm.eval.parser : OhmParser;
import ohm.settings : Settings;
import ohm.read : OhmReader;
import ohm.exceptions : ExitException, ContinueException;


class InteractiveConsole : Interactive {
public:
	Settings settings;
	OhmController controller;
	Reader reader;
	Output output;

	Location location;

public:
	this(Settings settings, Input input, Output output)
	{
		this.settings = settings;
		this.output = output;

		this.location = Location("ohm", 0, 0, 0);
		this.controller = new OhmController(settings);

		this.reader = new OhmReader(input, controller);
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
				output.writeOther(
					settings.showStackTraces ? e.toString() : e.msg
				);
			}

			location.line++;
		}
	}

	void repl()
	{
		reader.processInput(location, inputPrompt);

		auto state = controller.compile();
		auto result = controller.execute(state);

		output.writeResult(result.toString(), outputPrompt);
	}

protected:
	@property string inputPrompt()
	{
		return format("In [%d]: ", location.line + 1);
	}

	@property string outputPrompt()
	{
		return format("Out[%d]: ", location.line + 1);
	}
}