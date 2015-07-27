module ohm.interactive;

import std.string : format;

import ir = volt.ir.ir;
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

		reader.setCommand(`\t`, &printType);
		reader.setCommand(`\dump`, &dumpModule);
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
		reader.read(location, inputPrompt);

		auto state = controller.compile();
		auto result = controller.execute(state, location.line + 1);

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

	// Commands
	bool printType(string command, ref Location location, ref string source)
	{
		ir.Type type = null;
		if (source.length == 0) {
			type = controller.varStore.returnData.type;
		} else if(controller.varStore.has(source)) {
			type = controller.varStore.get(source).type;
		} else {
			// only compile if really required
			reader.process(location, source, false);
			auto state = controller.compile();
			auto result = controller.execute(state, location.line + 1);
			type = result.type;
		}

		if (type is null) {
			printer.writeln("void");
		} else {
			printer.print(type);
			printer.writeln("");
		}

		return false;
	}

	bool dumpModule(string command, ref Location location, ref string source)
	{
		controller.dumpModule();
		return false;
	}
}