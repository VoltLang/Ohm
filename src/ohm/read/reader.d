module ohm.read.reader;


import std.string : format;

import ir = volt.ir.ir;
import volt.token.location : Location;
import volt.exceptions : CompilerError;

import ohm.interfaces : Input, Reader;
import ohm.exceptions : ExitException, ContinueException;
import ohm.eval.controller : OhmController;
import ohm.read.parser : OhmParser;
import ohm.read.util : Balance, balancedParens;


enum Parens {
	Open = ['(', '[', '{'],
	Close = [')', ']', '}'],
}


class OhmReader : Reader
{
public:
	Input input;
	OhmController controller;

	@property
	OhmParser parser() in { assert(controller !is null); } body { return controller.frontend; }

public:
	this(Input input, OhmController controller)
	{
		this.input = input;
		this.controller = controller;
	}

	void processInput(Location location, string prompt)
	{
		// the parser will eat/ignore additional semicolons
		string source = input.getInput(prompt, &needsToReadMore) ~ ";";

		ir.TopLevelBlock tlb;
		ir.Node[] statements;

		parser.parseTopLevelsOrStatements(source, location, tlb, statements);

		controller.addTopLevel(tlb);
		controller.setStatements(statements);

		// don't compile if we did nothing but (re)set the statements
		if (statements.length == 0 && tlb.nodes.length == 0) {
			throw new ContinueException();
		}
	}

protected:
	int needsToReadMore(string soFar)
	{
		int indentLevel;
		auto balance = balancedParens(soFar, indentLevel);

		// return indentation level if not balanced, -1 otherwise
		return balance == Balance.BALANCED ? -1 : indentLevel;
	}
}