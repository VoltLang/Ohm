module ohm.util;


bool balancedParens(in const(char)[] inp, char open, char close, size_t maxDepth = -1)
{
	size_t balance = 0;

	foreach (c; inp) {
		if (c == open) {
			if (balance > maxDepth) {
				return false;
			}
			++balance;
		} else if (c == close) {
			if (balance <= 0) {
				return false;
			}
			--balance;
		}
	}

	return balance == 0;
}

bool balancedParens(in const(char[]) inp, const(char)[] open, const(char)[] close, size_t maxDepth = -1)
in { assert(open.length == close.length); }
body {
	for (size_t i = 0; i < open.length; ++i) {
		if (!balancedParens(inp, open[i], close[i], maxDepth)) {
			return false;
		}
	}

	return true;
}