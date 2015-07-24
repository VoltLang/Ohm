module ohm.interactive;

import std.string : format;

import volt.token.location : Location;
import volt.llvm.interfaces : State;
import volt.exceptions : CompilerError;

import ohm.interfaces : Interactive, Input, Output, Reader, Printer;
import ohm.settings : Settings;
import ohm.exceptions : ExitException, ContinueException;
import ohm.eval.controller : OhmController;
import ohm.eval.backend : OhmBackend;
import ohm.read.parser : OhmParser;
import ohm.read.reader : OhmReader;
import ohm.print.printer : OhmPrinter;


class InteractiveConsole : Interactive {
public:
	Settings settings;
	OhmController controller;
	Input input;
	Reader reader;
	Output output;
	Printer printer;

	Location location;

public:
	this(Settings settings, Input input, Output output)
	{
		this.settings = settings;
		this.input = input;
		this.output = output;

		this.location = Location("ohm", 0, 0, 0);
		this.controller = new OhmController(settings);

		this.reader = new OhmReader(input, controller);
		this.printer = new OhmPrinter(output, controller);
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
				output.writeln(
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

		printer.print(result, outputPrompt);
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