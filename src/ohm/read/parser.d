module ohm.read.parser;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;
import volt.errors;
import volt.token.stream;
import volt.token.location;
import volt.parser.base;
import volt.parser.declaration;
import volt.parser.toplevel;
import volt.parser.statements;
import volt.parser.expression;
import volt.parser.base : ParserStream;
import volt.parser.parser : VoltaParser = Parser, checkError;
import volt.token.location : Location;
import volt.token.lexer : lex;
import volt.token.source : Source;
import volt.token.stream : TokenType;


ParseStatus parseTopLevelsOrStatements(ParserStream ps, TokenType end, out ir.TopLevelBlock tlb, out ir.Node[] statements)
{
	tlb = new ir.TopLevelBlock();
	tlb.location = ps.peek.location;

	ps.pushCommentLevel();
	while (ps.peek.type != end && ps.peek.type != TokenType.End) {
		if (ifDocCommentsUntilEndThenSkip(ps)) {
			continue;
		}

		ir.TopLevelBlock tmp;
		auto succeeded = parseOneTopLevelOrStatement(ps, tmp, statements);
		if (!succeeded) {
			return succeeded;
		}
		if (tmp.nodeType != ir.NodeType.Attribute) {
			ps.popCommentLevel();
			ps.pushCommentLevel();
		}
		tlb.nodes ~= tmp.nodes;
	}
	ps.popCommentLevel();

	return Succeeded;
}

// this was copied from parseOneTopLevelBlock, only the default case was replaced with parseStatement
ParseStatus parseOneTopLevelOrStatement(ParserStream ps, out ir.TopLevelBlock tlb, ref ir.Node[] statements)
{
	auto succeeded = eatComments(ps);
	if (!succeeded) {
		return succeeded;
	}

	tlb = new ir.TopLevelBlock();
	tlb.location = ps.peek.location;

	switch (ps.peek.type) {
		case TokenType.Import:
			ir.Import _import;
			succeeded = parseImport(ps, _import);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			tlb.nodes ~= _import;
			break;
		case TokenType.Unittest:
			ir.Unittest u;
			succeeded = parseUnittest(ps, u);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			tlb.nodes ~= u;
			break;
		case TokenType.This:
			ir.Function c;
			succeeded = parseConstructor(ps, c);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			tlb.nodes ~= c;
			break;
		case TokenType.Tilde:  // XXX: Is this unambiguous?
			ir.Function d;
			succeeded = parseDestructor(ps, d);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			tlb.nodes ~= d;
			break;
		case TokenType.Union:
			ir.Union u;
			succeeded = parseUnion(ps, u);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			tlb.nodes ~= u;
			break;
		case TokenType.Struct:
			ir.Struct s;
			succeeded = parseStruct(ps, s);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			tlb.nodes ~= s;
			break;
		case TokenType.Class:
			ir.Class c;
			succeeded = parseClass(ps, c);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			tlb.nodes ~= c;
			break;
		case TokenType.Interface:
			ir._Interface i;
			succeeded = parseInterface(ps, i);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			tlb.nodes ~= i;
			break;
		case TokenType.Enum:
			ir.Node[] nodes;
			succeeded = parseEnum(ps, nodes);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			tlb.nodes ~= nodes;
			break;
		case TokenType.Mixin:
			auto next = ps.lookahead(1).type;
			if (next == TokenType.Function) {
				ir.MixinFunction m;
				succeeded = parseMixinFunction(ps, m);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.TopLevelBlock);
				}
				tlb.nodes ~= m;
			} else if (next == TokenType.Template) {
				ir.MixinTemplate m;
				succeeded = parseMixinTemplate(ps, m);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.TopLevelBlock);
				}
				tlb.nodes ~= m;
			} else {
				return unexpectedToken(ps, ir.NodeType.TopLevelBlock);
			}
			break;
		case TokenType.Const:
			if (ps.lookahead(1).type == TokenType.OpenParen) {
				goto default;
			} else {
				goto case;
			}
		case TokenType.At:
			if (ps.lookahead(1).type == TokenType.Interface) {
				ir.UserAttribute ui;
				succeeded = parseUserAttribute(ps, ui);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.TopLevelBlock);
				}
				tlb.nodes ~= ui;
				break;
			} else {
				goto case;
			}
			// TODO work around 'goto case' || 'cfg' bug.
			// Need to have something here because of 'cfg' bug.
			// Can't be assert(false) because of 'goto case' bug.
			version (Volt) goto case;
		case TokenType.Extern:
		case TokenType.Align:
		case TokenType.Deprecated:
		case TokenType.Private:
		case TokenType.Protected:
		case TokenType.Package:
		case TokenType.Public:
		case TokenType.Export:
		case TokenType.Final:
		case TokenType.Synchronized:
		case TokenType.Override:
		case TokenType.Abstract:
		case TokenType.Global:
		case TokenType.Local:
		case TokenType.Inout:
		case TokenType.Nothrow:
		case TokenType.Pure:
			ir.Attribute a;
			succeeded = parseAttribute(ps, a);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			tlb.nodes ~= a;
			break;
		case TokenType.Version:
		case TokenType.Debug:
			ir.ConditionTopLevel c;
			succeeded = parseConditionTopLevel(ps, c);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			tlb.nodes ~= c;
			break;
		case TokenType.Static:
			auto next = ps.lookahead(1).type;
			if (next == TokenType.Tilde) {
				goto case TokenType.Tilde;
			} else if (next == TokenType.This) {
				goto case TokenType.This;
			} else if (next == TokenType.Assert) {
				ir.StaticAssert s;
				succeeded = parseStaticAssert(ps, s);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.TopLevelBlock);
				}
				tlb.nodes ~= s;
			} else if (next == TokenType.If) {
				goto case TokenType.Version;
			} else {
				ir.Attribute a;
				succeeded = parseAttribute(ps, a);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.TopLevelBlock);
				}
				tlb.nodes ~= a;
			}
			break;
		case TokenType.Semicolon:
			// Just ignore EmptyTopLevel
			ps.get();
			break;
		default:
			auto sink = new NodeSink();
			succeeded = parseStatement(ps, sink.push);
			if (!succeeded) {
				return succeeded;
			}

			foreach (statement; sink.array) {
				// TODO check if more needs to be stored in the tlb
				if (statement.nodeType == ir.NodeType.Function) {
					tlb.nodes ~= cast(ir.Function) statement;
				} else {
					statements ~= statement;
				}
			}
			break;
	}

	//assert(tlb.nodes[$-1] !is null);
	return Succeeded;

}


class OhmParser : VoltaParser
{
public:
	ir.TopLevelBlock parseToplevel(string source, Location loc)
	{
		auto src = new Source(source, loc.filename);
		src.location = loc;
		auto ps = new ParserStream(lex(src));
		if (dumpLex)
			doDumpLex(ps);

		ps.get(); // Skip, stream already checks for Begin.

		ir.TopLevelBlock tlb;
		checkError(ps, parseTopLevelBlock(ps, tlb, TokenType.End));
		return tlb;
	}

	void parseTopLevelsOrStatements(string source, Location loc, out ir.TopLevelBlock tlb, out ir.Node[] statements)
	{
		auto src = new Source(source, loc.filename);
		src.location = loc;
		auto ps = new ParserStream(lex(src));
		if (dumpLex)
			doDumpLex(ps);

		ps.get(); // Skip, stream already checks for Begin.

		checkError(ps, .parseTopLevelsOrStatements(ps, TokenType.End, tlb, statements));
	}
}
