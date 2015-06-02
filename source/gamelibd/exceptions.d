module gamelibd.exceptions;

public mixin template ExceptionCtorMixin() {
	this(string msg = null, Throwable next = null) { super(msg, next); }
	this(string msg, string file, size_t line, Throwable next = null) {
		super(msg, file, line, next);
	}
}

class NullPointerException : Exception 
{
	mixin ExceptionCtorMixin;
}

class IoException : Exception
{
	mixin ExceptionCtorMixin;
}

class EofException : IoException
{
	mixin ExceptionCtorMixin;
}

class IndexOutOfBoundException : Exception
{
	mixin ExceptionCtorMixin;
}

