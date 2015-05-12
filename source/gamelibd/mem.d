module gamelibd.mem;

import std.traits;
import std.stdio;

import gamelibd.exceptions;

class Ref(T)
{
	private T _data;
	public void delegate (T _data) deleter;

	void opAssign(T another)
	{
		_data = cast(T) another;
	}

	this(T initializer)
	{
		opAssign(initializer);
	}

	this(T initializer, void delegate (T ) deleter)
	{
		this._data = initializer;
		this.deleter = deleter;
	}
	
	@property ref inout(T) get() inout
	{
		if(_data is null)
		{
			throw new NullPointerException();
		}
		return _data;
	}
	
	//alias get this;

	@property T internal() 
	{
		return _data;
	}


	public ~this()
	{
		free();
	}

	public void free()
	{
		if(_data is null)
		{
			return;
		}
		if(deleter !is null)
		{
			deleter(_data);
		}
		_data = null;
	}
}

struct Ptr(T)
{
	private Ref!T _data;

	void opAssign(T another)
	{
		if(_data is null)
		{
			_data = new Ref!T(another);
		}
		_data._data = another;
	}
	
	void opAssign(typeof(this) another)
	{
		if(_data is null)
		{
			_data = new Ref!T(null);
		}
		_data = another._data;
	}
	
	this(T initializer)
	{
		opAssign(initializer);
	}

	this(T initializer, void delegate (T ) deleter)
	{
		_data = new Ref!T(initializer,deleter);
	}

	@property ref inout(T) get() inout
	{
		if(_data is null)
		{
			throw new NullPointerException();
		}
		return _data.get;
	}
	
	alias get this;

	@property T internal()
	{
		if(_data is null)
		{
			return null;
		}
		return _data.internal();
	}

	public @property bool isNull()
	{
		return internal() is null;
	}

	public @property bool isNotNull()
	{
		return internal() !is null;
	}

	public void free()
	{
		if(_data is null)
		{
			return;
		}
		_data.free();
	}
}

class mem
{
	public static T heapAllocate(T, Args...) (Args args) 
	{
		import std.conv : emplace;
		import core.stdc.stdlib : malloc;
		import core.memory : GC;
		
		// get class size of class instance in bytes
		auto size = __traits(classInstanceSize, T);
		
		// allocate memory for the object
		auto memory = malloc(size)[0..size];
		if(!memory)
		{
			import core.exception : onOutOfMemoryError;
			onOutOfMemoryError();
		}                    
		
		//writeln("Memory allocated");
		
		// notify garbage collector that it should scan this memory
		//GC.addRange(memory.ptr, size);
		
		// call T's constructor and emplace instance on
		// newly allocated memory
		return emplace!(T, Args)(memory, args);                                    
	}
	
	public static T* heapAllocateStruct(T, Args...) (Args args) 
	{
		import std.conv : emplace;
		import core.stdc.stdlib : malloc;
		import core.memory : GC;
		
		// get class size of class instance in bytes
		auto size = T.sizeof;
		
		// allocate memory for the object
		auto memory = malloc(size)[0..size];
		if(!memory)
		{
			import core.exception : onOutOfMemoryError;
			onOutOfMemoryError();
		}                    
		
		//writeln("Memory allocated");
		
		// notify garbage collector that it should scan this memory
		//GC.addRange(memory.ptr, size);
		
		// call T's constructor and emplace instance on
		// newly allocated memory
		return emplace!(T, Args)(memory, args);                                    
	}
	
	public static void heapDeallocate(T)(T obj) 
	{
		import core.stdc.stdlib : free;
		import core.memory : GC;
		
		// calls obj's destructor
		destroy(obj); 
		
		// garbage collector should no longer scan this memory
		//GC.removeRange(cast(void*)obj);
		
		// free memory occupied by object
		free(cast(void*)obj);
		
		//writeln("Memory deallocated");
	}
}

