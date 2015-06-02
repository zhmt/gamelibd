module gamelibd.exceptions;

class NullPointerException : Exception 
{
	this()
	{
		super("NullPointerException");
	}
	
	this(string msg)
	{
		super("NullPointerException" ~ msg);
	}
}

class IoException : Exception
{
	this()
	{
		super("NetException");
	}
	
	this(string msg)
	{
		super("NullPointerException " ~ msg);
	}
}

class EofException : IoException
{
	this()
	{
		super("EofException");
	}
}

class IndexOutOfBoundException : Exception
{
	this(long index, long max)
	{
		import std.string;
		super(format("%s exceeds %s.",index, max));
	}
}

