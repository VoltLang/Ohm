module ohm.exceptions;


class CompilerException : Exception
{
public:
    this(string message, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line);
    }
}