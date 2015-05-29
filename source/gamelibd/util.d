module gamelibd.util;

import std.stdio;
import gamelibd.mem;

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

class LinkedList(T)
{
	class Node
	{
		public this(T value,Node last,Node next)
		{
			this.value = value;
			this.last = last;
			this.next = next;
		}

		T value;
		Node last;
		Node next;
	}

	Node head;
	Node tail;
	int _size;

	public this()
	{
		//init a blank head
		head = new Node(null,null,null);
		tail = head;
		_size = 0;
	}

	public void addTail(T value)
	{
		Node node = new Node(value,tail,null);
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
		Node tmp = head.next;
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
		if(index<0|| index>=_size)
		{
			throw new Exception("IndexOutOfBound");
		}

		Node tmp = head.next;
		for(int i=0; i<=index; i++)
		{
			if(i==index)
			{
				return tmp.value;
			}
			tmp = tmp.next;
		}
		throw new Exception("IndexOutOfBound");
	}
}

unittest 
{
	import std.exception;
	void testGet()
	{
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
}