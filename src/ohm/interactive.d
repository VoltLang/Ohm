module ohm.interactive;

import std.string : format, toLower, strip;
import std.array : split;
import std.algorithm : canFind;

import ir = volt.ir.ir;
import volt.token.location : Location;
import volt.semantic.classify : isVoid;
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

			controller.push();
			try {
				repl();
			} catch (ContinueException e) {
				continue;
			} catch (ExitException e) {
				break;
			} catch (CompilerError e) {
				controller.pop();
				printer.writeln(
					settings.showStackTraces ? e.toString() : e.msg
				);
			}
		}
	}

	void repl()
	{
		reader.read(location, inputPrompt);

		auto result = controller.run(location.line + 1);

		printer.print(result, outputPrompt);
	}

	void close()
	{
		controller.close();
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
			auto result = controller.run(location.line + 1);
			type = result.type;
		}

		if (type !is null && !isVoid(type)) {
			printer.print(type);
			printer.writeln("");
		}

		return false;
	}

	bool dumpModule(string command, ref Location location, ref string source)
	{
		source = toLower(strip(source));
		if (source.length == 0) {
			controller.dumpModule();
			controller.dumpIR();
			return false;
		}

		auto ss = split(source);
		if (canFind(ss, "mod", "module")) {
			controller.dumpModule();
		}
		if (canFind(ss, "ir")) {
			controller.dumpIR();
		}

		return false;
	}
}