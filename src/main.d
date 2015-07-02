import std.stdio;

import std.conv : to;

import ir = volt.ir.ir;
import volt.interfaces : Controller, Settings, Platform, Arch;
import volt.token.location : Location;
import volt.parser.parser : Parser;
import volt.llvm.interfaces : State;

import lib.llvm.executionengine;
import lib.llvm.analysis;
import lib.llvm.core;

import ohm.volta.controller : OhmController;
import ohm.interactive : Interactive, InteractiveConsole;


void main(string[] args) {
	Settings settings = new Settings(".");
	setDefault(settings);
	foreach (arg; args) {
		if (arg == "--dbg") settings.internalDebug = true;
	}

	Interactive interactive = new InteractiveConsole(settings, stdin, stdout);
	interactive.run();
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
