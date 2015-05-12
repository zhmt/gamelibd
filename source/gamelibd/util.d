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

	public this()
	{
		//init a blank head
		head = new Node(null,null,null);
		tail = head;
	}

	public void addTail(T value)
	{
		Node node = new Node(value,tail,null);
		tail.next = node;
		tail = node;
	}

	public @property bool isEmpty()
	{
		return head == tail;
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
		return ret;
	}
}

