module ohm.exceptions;


class OhmException : Exception
{
public:
	this(string message = "", string file = __FILE__, size_t line = __LINE__)
	{
		super(message, file, line);
	}
}


class ContinueException : Exception
{
	this(string message = "", string file = __FILE__, size_t line = __LINE__)
	{
		super(message, file, line);
	}
}


class ExitException : OhmException
{
public:
	this(string message = "", string file = __FILE__, size_t line = __LINE__)
	{
		super(message, file, line);
	}
}