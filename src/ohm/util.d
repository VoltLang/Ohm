module ohm.util;


enum Balance
{
	BALANCED,
	UNBALANCED,
	UNBALANCABLE
}


int balancedParens(in const(char)[] inp, char open, char close)
{
	int balance = 0;

	foreach (c; inp) {
		if (c == open) {
			++balance;
		} else if (c == close) {
			if (balance <= 0) {
				// this can't be balanced anymore e.g.
				// void function () }
				//                  ^
				return -1;
			}
			--balance;
		}
	}

	return balance;
}

int balancedParens(in const(char[]) inp, const(char)[] open, const(char)[] close)
in { assert(open.length == close.length); }
body {
	int totalBalance = 0;

	for (size_t i = 0; i < open.length; ++i) {
		auto r = balancedParens(inp, open[i], close[i]);

		if (r == -1) {
			// this can't be balanced anymore
			return -1;
		}

		totalBalance += r;
	}

	return totalBalance;
}