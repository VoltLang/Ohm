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
	OhmController controller;
	Reader reader;
	Printer printer;

	Location location;

	@property ref Settings settings() { return controller.settings; }

protected:
	this(OhmController controller, Reader reader, Printer printer)
	{
		this.controller = controller;

		this.reader = reader;
		this.printer = printer;

		this.location = Location("ohm", 0, 0, 0);
	}

public:
	this(Settings settings, Input input, Output output)
	{
		auto controller = new OhmController(settings);
		this(
			controller,
			new OhmReader(input, controller),
			new OhmPrinter(output, controller)
		);
	}

	void run()
	{
		for (size_t line = location.line;;line++) {
			location.line = line;

			try {
				repl();
			} catch (ContinueException e) {
				continue;
			} catch (ExitException e) {
				break;
			} catch (CompilerError e) {
				printer.writeln(
					settings.showStackTraces ? e.toString() : e.msg
				);
			}
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