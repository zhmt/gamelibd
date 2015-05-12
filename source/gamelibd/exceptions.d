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

