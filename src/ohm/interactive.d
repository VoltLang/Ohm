module ohm.interactive;

import std.string : format, toLower, strip;
import std.array : split;
import std.algorithm : canFind;

import ir = volt.ir.ir;
import volt.token.location : Location;
import volt.semantic.classify : isVoid;
import volt.llvm.interfaces : State;
import volt.exceptions : CompilerException;
import volt.interfaces : VersionSet;

import ohm.interfaces : Interactive, Input, Output, Reader, Printer;
import ohm.settings : Settings;
import ohm.exceptions : ExitException, ContinueException;
import ohm.eval.driver : OhmDriver;
import ohm.eval.backend : OhmBackend;
import ohm.read.parser : OhmParser;
import ohm.read.reader : OhmReader;
import ohm.print.printer : OhmPrinter;


class InteractiveConsole : Interactive {
public:
	OhmDriver driver;
	Reader reader;
	Printer printer;

	Location location;

	@property ref Settings settings() { return driver.settings; }

protected:
	this(OhmDriver driver, Reader reader, Printer printer)
	{
		this.driver = driver;

		this.reader = reader;
		this.printer = printer;

		this.location = Location("ohm", 0, 0, 0);
	}

public:
	this(VersionSet ver, Settings settings, Input input, Output output)
	{
		auto driver = new OhmDriver(ver, settings);
		this(
			driver,
			new OhmReader(input, driver),
			new OhmPrinter(output, driver)
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
			} catch (CompilerException e) {
				printer.writeln(
					settings.showStackTraces ? e.toString() : e.msg
				);
			}
		}
	}

	void repl()
	{
		driver.push();
		scope(failure) driver.pop();

		reader.read(location, inputPrompt);

		auto result = driver.run(location.line + 1);

		printer.print(result, outputPrompt);
	}

	void close()
	{
		driver.close();
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
			type = driver.varStore.returnData.type;
		} else if(driver.varStore.has(source)) {
			type = driver.varStore.get(source).type;
		} else {
			// only compile if really required
			reader.process(location, source, false);
			auto result = driver.run(location.line + 1);
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
			driver.dumpModule();
			driver.dumpIR();
			return false;
		}

		auto ss = split(source);
		if (canFind(ss, "mod", "module")) {
			driver.dumpModule();
		}
		if (canFind(ss, "ir")) {
			driver.dumpIR();
		}

		return false;
	}
}