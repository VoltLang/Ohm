module ohm.volta.parser;

import ir = volt.ir.ir;
import volt.parser.base : match;
import volt.parser.toplevel : parseTopLevelBlock;
import volt.parser.parser : VoltaParser = Parser;
import volt.token.location : Location;
import volt.token.lexer : lex;
import volt.token.source : Source;
import volt.token.stream : TokenType;


class Parser : VoltaParser
{
public:
	ir.TopLevelBlock parseToplevel(string source, Location loc, bool inModule = false)
	{
		auto src = new Source(source, loc);
		auto ts = lex(src);
		if (dumpLex)
			doDumpLex(ts);

		match(ts, TokenType.Begin);

		return parseTopLevelBlock(ts, TokenType.End, inModule);
	}
}
