module ohm.read.util;


import std.algorithm : canFind;


enum Balance {
	NOT_BALANCEABLE = -1,
	IMBALANCED = 0,
	BALANCED = 1
}

enum Parens {
	OPEN = ['(', '[', '{'],
	CLOSE = [')', ']', '}']
}
enum STRING_CHARS = ['\'', '`', '"'];
enum ESCAPE = '\\';


Balance balancedParens(in char[] inp, out int indentLevel)
{
	return balancedParens(inp, Parens.OPEN, Parens.CLOSE, STRING_CHARS, ESCAPE, indentLevel);
}

Balance balancedParens(in char[] inp, in char[] open, in char[] close, in char[] stringChars, char escape, out int indentLevel)
{
	int balance = 0;

	size_t index = 0;
	bool inString = false;
	char oldStrChar = 0;

	while (index < inp.length) {
		char c = inp[index++];

		if (c == escape) {
			// skip the next char
			index++;
			continue;
		}

		if (canFind(stringChars, c)) {
			if (inString) {
				if (c == oldStrChar) {
					inString = false;
				}
			} else {
				inString = true;
				oldStrChar = c;
			}
		}

		if (inString)
			continue;

		if (canFind(open, c)) {
			balance++;
		} else if (canFind(close, c)) {
			if (balance <= 0) {
				// this can't be balanced anymore e.g.
				// void function () }
				//                  ^
				return Balance.NOT_BALANCEABLE;
			}

			balance--;
		}

	}

	indentLevel = balance;
	return balance == 0 && !inString ? Balance.BALANCED : Balance.IMBALANCED;
}


unittest {
	int indentLevel;

	assert(balancedParens("[", indentLevel) == Balance.IMBALANCED);
	assert(indentLevel == 1);
	assert(balancedParens("]", indentLevel) == Balance.NOT_BALANCEABLE);
	assert(balancedParens("[]", indentLevel) == Balance.BALANCED);
	assert(indentLevel == 0);
	assert(balancedParens("`[`", indentLevel) == Balance.BALANCED);
	assert(indentLevel == 0);
	assert(balancedParens("`]`", indentLevel) == Balance.BALANCED);
	assert(indentLevel == 0);
	assert(balancedParens("`[]", indentLevel) == Balance.IMBALANCED);
	assert(indentLevel == 0);
	assert(balancedParens("`[\\]", indentLevel) == Balance.IMBALANCED);
	assert(indentLevel == 0);
	assert(balancedParens("\\`[]", indentLevel) == Balance.BALANCED);
	assert(indentLevel == 0);
	assert(balancedParens("\\`[\\]", indentLevel) == Balance.IMBALANCED);
	assert(indentLevel == 1);
}