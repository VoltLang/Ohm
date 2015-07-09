module lib.readline.readline;


private {
	import core.stdc.stdlib : free;
	import std.string : toStringz;
	import std.conv : to;
}
public import lib.readline.c.readline;


alias readline = lib.readline.c.readline.readline;
alias rl_replace_line = lib.readline.c.readline.rl_replace_line;
alias rl_insert_text = lib.readline.c.readline.rl_insert_text;


string readline(const(char)[] prompt)
{
	auto s = readline(toStringz(prompt));
	scope(exit) free(s);
	if (s is null) {
		return null;
	}
	string r = to!string(s);
	return r is null ? "" : r;
}


void rl_replace_line(const(char)[] text, int clear_undo)
{
	rl_replace_line(toStringz(text), clear_undo);
}

int rl_insert_text(const(char)[] text)
{
	return rl_insert_text(toStringz(text));
}