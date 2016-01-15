import std.stdio;

import std.stdio : File, writeln, writefln;
import std.string : chomp, toLower;
import std.path : absolutePath;
version (Windows) {
	import std.file : SpanMode, dirEntries;
	import std.path : baseName, dirName;
}

import volt.interfaces : VersionSet, Platform, Arch;
import volt.errors : CompilerError;
import volt.license;
import volt.driver;
import watt.path;

import ohm.interfaces : Input, Output, Interactive;
import ohm.interactive : InteractiveConsole;
import ohm.io : StdinReadlineInput, StdoutOutput;
import ohm.settings : Settings, expandTilde;


int main(string[] args)
{
	string[] files;
	auto cmd = args[0];
	args = args[1 .. $];

	auto settings = new Settings(getExecDir());
	setDefault(settings);

	auto ver = new VersionSet();

	if (!handleArgs(getConfigLines(), files, ver, settings))
		return 0;

	if (!handleArgs(args, files, ver, settings))
		return 0;

	settings.processConfigs(ver);

	if (files.length > 0) {
		writefln("%s: unexpected arguments: %s", cmd, files);
		return 0;
	}

	settings.historyFile = absolutePath(expandTilde(settings.historyFile));

	Input input = new StdinReadlineInput(settings);
	Output output = new StdoutOutput();

	Interactive interactive;
	try {
		interactive = new InteractiveConsole(ver, settings, input, output);
	} catch (CompilerError e) {
		writeln(e.msg);
		return 1;
	}

	{
		scope(exit) interactive.close();
		interactive.run();
	}

	return 0;
}


bool handleArgs(string[] args, ref string[] files, VersionSet ver, Settings settings)
{
	void delegate(string) argHandler;
	int i;

	// Handlers.
	void includePath(string path) {
		settings.includePaths ~= path;
	}

	void versionIdentifier(string ident) {
		ver.setVersionIdentifier(ident);
	}

	void libraryFile(string file) {
		settings.libraryFiles ~= file;
	}

	void libraryPath(string path) {
		settings.libraryPaths ~= path;
	}

	void stdFile(string file) {
		settings.stdFiles ~= file;
	}

	void stdIncludePath(string path) {
		settings.stdIncludePaths ~= path;
	}

	void historyFile(string file) {
		settings.historyFile = file;
	}

	foreach(arg; args)  {
		if (argHandler !is null) {
			argHandler(arg);
			argHandler = null;
			continue;
		}

		// Handle @file.txt arguments.
		if (arg.length > 0 && arg[0] == '@') {
			string[] lines;
			if (!getLinesFromFile(arg[1 .. $], lines)) {
				writefln("can not find file \"%s\"", arg[1 .. $]);
				return false;
			}

			if (!handleArgs(lines, files, ver, settings))
				return false;

			continue;
		}

		switch (arg) {
		case "--help", "-h":
			return printUsage();
		case "-license", "--license":
			return printLicense();
		case "-I":
			argHandler = &includePath;
			continue;
		case "--stdlib-I":
			argHandler = &stdIncludePath;
			continue;
		case "--stdlib-file":
			argHandler = &stdFile;
			continue;
		case "-L":
			argHandler = &libraryPath;
			continue;
		case "-l":
			argHandler = &libraryFile;
			continue;
		case "--history":
			argHandler = &historyFile;
			continue;
		case "--ignore-assign":
			settings.ignoreAssignExpValue = true;
			continue;
		case "--stacktrace":
			settings.showStackTraces = true;
			continue;
		case "-D":
			argHandler = &versionIdentifier;
			continue;
		case "-w":
			settings.warningsEnabled = true;
			continue;
		case "-d":
			ver.debugEnabled = true;
			continue;
		case "--simple-trace":
			settings.simpleTrace = true;
			continue;
		case "--internal-dbg":
			settings.internalDebug = true;
			continue;
		default:
		}

		version (Windows) {
			auto barg = baseName(arg);
			if (barg.length > 2 && barg[0 .. 2] == "*.") {
				foreach (file; dirEntries(dirName(arg), barg, SpanMode.shallow)) {
					files ~= file;
				}
				continue;
			}
		}

		files ~= arg;
	}

	if (files.length > 1 && settings.docOutput.length > 0) {
		writefln("-do flag incompatible with multiple modules");
		return false;
	}

	return true;
}

string[] getConfigLines()
{
	string[] lines;
	string file = getExecDir() ~ dirSeparator ~ "ohm.conf";
	getLinesFromFile(file, lines);
	return lines;
}

bool getLinesFromFile(string file, ref string[] lines)
{
	try {
		auto f = File(file);
		foreach(line; f.byLine) {
			if (line.length > 0 && line[0] != '#') {
				lines ~= chomp(line).idup;
			}
		}
	} catch {
		return false;
	}
	return true;
}


void setDefault(Settings settings)
{
	// Only MinGW is supported.
	version (Windows) {
		settings.platform = Platform.MinGW;
	} else version (linux) {
		settings.platform = Platform.Linux;
	} else version (OSX) {
		settings.platform = Platform.OSX;
	} else {
		static assert(false);
	}

	version (X86) {
		settings.arch = Arch.X86;
	} else version (X86_64) {
		settings.arch = Arch.X86_64;
	} else {
		static assert(false);
	}
}

bool printUsage()
{
	writefln("usage: ohm [options]");
	// basic options
	writefln("\t-h,--help        Print this message and quit.");
	writefln("\t--license        Print license information and quit.");
	writeln();
	// include options
	writefln("\t-I path          Add a include path.");
	writefln("\t--stdlib-I       Apply this include before any other -I.");
	writefln("\t--stdlib-file    Apply this file first but only when linking");
	writefln("\t                 (ignored if --no-stdlib was given).");
	writefln("\t-L path          Add a library path.");
	writefln("\t-l path          Add a library.");
	writeln();
	// ohm specific options
	writefln("\t--history        Path to Ohm history file.");
	writefln("\t--ignore-assign  Don't print the value of an assign expression.");
	writefln("\t--stacktrace     Show stacktraces instead of small error messages.");
	writefln("\t                 Only useful for debugging Ohm.");
	writeln();
	// other options
	writefln("\t-D ident         Define a new version flag");
	writefln("\t-w               Enable warnings.");
	writefln("\t-d               Compile in debug mode.");
	writeln();
	// volt debug options
	writefln("\t--simple-trace   Print the name of functions to stdout as they're run.");
	writefln("\t--internal-dbg   Enables internal debug printing.");
	writeln();

	return false;
}

bool printLicense()
{
	foreach(license; licenseArray)
		writefln(license);
	return false;
}
