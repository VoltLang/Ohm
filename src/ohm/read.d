module ohm.read;


import std.string : format;

import ir = volt.ir.ir;
import volt.token.location : Location;
import volt.exceptions : CompilerError;

import ohm.interfaces : Input, Reader;
import ohm.exceptions : ExitException, ContinueException;
import ohm.eval.controller : OhmController;
import ohm.eval.parser : OhmParser;
import ohm.util : balancedParens;


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
		ir.Statement[] statements;

		parser.parseTopLevelsOrStatements(source, location, tlb, statements);

		controller.addTopLevel(tlb);
		if (statements.length == 0) {
			throw new ContinueException();
		}
		controller.setStatements(statements);
	}

protected:
	int needsToReadMore(string soFar)
	{
		// TODO improve, e.g.:
		// "{" is unbalanced even though the brace is inside a string.
		auto balance = balancedParens(soFar, Parens.Open, Parens.Close);

		// return the balance level (indentation), if it is balanced (0)
		// no more input required.
		return balance > 0 ? balance : -1;
	}
}