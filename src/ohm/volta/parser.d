module ohm.volta.parser;

import ir = volt.ir.ir;
import volt.parser.base : match;
import volt.parser.toplevel : parseTopLevelBlock;
import volt.parser.parser : VoltaParser = Parser;
import volt.token.location : Location;
import volt.token.lexer : lex;
import volt.token.source : Source;
import volt.token.stream : TokenType;


ir.Node[] removeEmptyNodes(ir.Node[] nodes) {
	ir.Node[] result;

	foreach (node; nodes) {
		switch (node.nodeType()) with (ir.NodeType) {
			case EmptyTopLevel:
			case EmptyStatement:
				continue;
			default:
				result ~= node;
		}
	}

	return result;
}


class OhmParser : VoltaParser
{
public:
	ir.TopLevelBlock parseToplevel(string source, Location loc, bool inModule = false)
	{
		auto src = new Source(source, loc);
		auto ts = lex(src);
		if (dumpLex)
			doDumpLex(ts);

		match(ts, TokenType.Begin);

		auto tlb = parseTopLevelBlock(ts, TokenType.End, inModule);
		tlb.nodes = removeEmptyNodes(tlb.nodes);
		return tlb;
	}

	override ir.Node[] parseStatements(string source, Location loc)
	{
		return removeEmptyNodes(super.parseStatements(source, loc));
	}

}
