module gamelibd.util;

import std.stdio;
import gamelibd.mem;
import std.exception;
import gamelibd.exceptions;


public static long utcNow()
{
	import std.datetime;
	long stdtime = Clock.currStdTime();
	
	import core.time;
	auto ret = convert!("hnsecs", "msecs")(stdtime - 621_355_968_000_000_000L);
	
	return ret;
}

void writeFlush(T...)(T args)
{
	writeln(args);
	stdout.flush();
}

class Node(T)
{
	public this(T value,Node last,Node next)
	{
		this.value = value;
		this.last = last;
		this.next = next;
	}
	
	T value;
	Node!T last;
	Node!T next;
}

class LinkedList(T)
{
	Node!T head;
	Node!T tail;
	int _size;

	public this()
	{
		//init a blank head
		head = new Node!T(null,null,null);
		tail = head;
		_size = 0;
	}

	public void addTail(T value)
	{
		Node!T node = new Node!T(value,tail,null);
		tail.next = node;
		tail = node;
		_size ++;
	}

	public @property bool isEmpty()
	{
		return head == tail;
	}

	public @property int size()
	{
		return _size;
	}

	public T removeHead()
	{
		Node!T tmp = head.next;
		scope(exit) delete tmp;
		T ret = tmp.value;

		head.next = tmp.next;
		if(head.next !is null)
		{
			head.next.last = head;
		}else
		{
			tail = head;
		}

//		writeFlush("remove from q");
		_size--;
		return ret;
	}

	public T get(int index)
	{
		//if(index<0|| index>=_size)
		enforce!IndexOutOfBoundException(index>=0&&index<_size);

		Node!T tmp = head.next;
		for(int i=0; i<=index; i++)
		{
			if(i==index)
			{
				return tmp.value;
			}
			tmp = tmp.next;
		}
		enforce!IndexOutOfBoundException(true);
		return tmp.value;
	}
}

unittest 
{
	import std.exception;
	void testGet()
	{
		LinkedList!string list1 = new LinkedList!string();
		assertThrown( list1.get(-1));
		assertThrown( list1.get(0));
		list1.addTail("a");
		assert (list1.get(0)=="a");


		LinkedList!string list = new LinkedList!string();
		assertThrown( list.get(-1));
		assertThrown( list.get(0));
		list.addTail("a");
		assert (list.get(0)=="a");
		assert (list.size ==1);
		list.addTail("b");
		assert (list.get(0)=="a");
		assert (list.get(1)=="b");
		assert (list.size ==2);
		list.addTail("c");
		assert (list.get(0)=="a");
		assert (list.get(1)=="b");
		assert (list.get(2)=="c");
		assert (list.size ==3);
		assertThrown( list.get(3));
		assertThrown( list.get(4));
	}

	testGet();
}