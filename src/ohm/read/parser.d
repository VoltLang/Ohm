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
import volt.parser.parser : VoltaParser = Parser;
import volt.token.location : Location;
import volt.token.lexer : lex;
import volt.token.source : Source;
import volt.token.stream : TokenType, TokenStream;


void parseTopLevelsOrStatements(TokenStream ts, TokenType end, out ir.TopLevelBlock tlb, out ir.Statement[] statements, bool inModule = false)
{
	tlb = new ir.TopLevelBlock();
	tlb.location = ts.peek.location;

	ts.pushCommentLevel();
	while (ts.peek.type != end && ts.peek.type != TokenType.End) {
		if (ifDocCommentsUntilEndThenSkip(ts)) {
			continue;
		}

		parseOneTopLevelOrStatement(ts, tlb, statements, inModule);
	}
	ts.popCommentLevel();
}

// this was copied from parseOneTopLevelBlock, only the default case was replaced with parseStatement
void parseOneTopLevelOrStatement(TokenStream ts, ir.TopLevelBlock tlb, ref ir.Statement[] statements, bool inModule)
{
	eatComments(ts);
	scope(exit) eatComments(ts);

	switch (ts.peek.type) {
	case TokenType.Import:
		tlb.nodes ~= [parseImport(ts, inModule)];
		break;
	case TokenType.Unittest:
		tlb.nodes ~= [parseUnittest(ts)];
		break;
	case TokenType.This:
		tlb.nodes ~= [parseConstructor(ts)];
		break;
	case TokenType.Tilde:  // XXX: Is this unambiguous?
		tlb.nodes ~= [parseDestructor(ts)];
		break;
	case TokenType.Union:
		tlb.nodes ~= [parseUnion(ts)];
		break;
	case TokenType.Struct:
		tlb.nodes ~= [parseStruct(ts)];
		break;
	case TokenType.Class:
		tlb.nodes ~= [parseClass(ts)];
		break;
	case TokenType.Interface:
		tlb.nodes ~= [parseInterface(ts)];
		break;
	case TokenType.Enum:
		tlb.nodes ~= parseEnum(ts);
		break;
	case TokenType.Mixin:
		auto next = ts.lookahead(1).type;
		if (next == TokenType.Function) {
			tlb.nodes ~= [parseMixinFunction(ts)];
		} else if (next == TokenType.Template) {
			tlb.nodes ~= [parseMixinTemplate(ts)];
		} else {
			auto err = ts.lookahead(1);
			throw makeExpected(err.location, "'function' or 'template'");
		}
		break;
	case TokenType.Const:
		if (ts.lookahead(1).type == TokenType.OpenParen) {
			goto default;
		} else {
			goto case;
		}
	case TokenType.At:
		if (ts.lookahead(1).type == TokenType.Interface) {
			tlb.nodes ~= [parseUserAttribute(ts)];
			break;
		} else {
			goto case;
		}
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
		tlb.nodes ~= [parseAttribute(ts, inModule)];
		break;
	case TokenType.Version:
	case TokenType.Debug:
		tlb.nodes ~= [parseConditionTopLevel(ts, inModule)];
		break;
	case TokenType.Static:
		auto next = ts.lookahead(1).type;
		if (next == TokenType.Tilde) {
			goto case TokenType.Tilde;
		} else if (next == TokenType.This) {
			goto case TokenType.This;
		} else if (next == TokenType.Assert) {
			tlb.nodes ~= [parseStaticAssert(ts)];
		} else if (next == TokenType.If) {
			goto case TokenType.Version;
		} else {
			tlb.nodes ~= [parseAttribute(ts, inModule)];
		}
		break;
	case TokenType.Semicolon:
		// Just ignore EmptyTopLevel
		match(ts, TokenType.Semicolon);
		break;
	default:
		foreach (statement; parseStatement(ts)) {
			// TODO check if more needs to be stored in the tlb
			if (statement.nodeType == ir.NodeType.Function) {
				tlb.nodes ~= cast(ir.Function) statement;
			} else {
				statements ~= statement;
			}
		}
		break;
	}
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

		return parseTopLevelBlock(ts, TokenType.End, inModule);
	}

	void parseTopLevelsOrStatements(string source, Location loc, out ir.TopLevelBlock tlb, out ir.Statement[] statements, bool inModule = false)
	{
		auto src = new Source(source, loc);
		auto ts = lex(src);
		if (dumpLex)
			doDumpLex(ts);

		match(ts, TokenType.Begin);

		.parseTopLevelsOrStatements(ts, TokenType.End, tlb, statements, inModule);
	}

	override ir.Node[] parseStatements(string source, Location loc)
	{
		return super.parseStatements(source, loc);
	}

}
