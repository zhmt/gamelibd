module gamelibd.Buf;

import gamelibd.net.conn;
import gamelibd.util;

class Buf
{


	private LinkedList!(ubyte[]) list = new LinkedList!(ubyte[])();
	private int firstBlockOffset;
	private int lastBlockEndIndex;
	private int ridx;
	private int widx;

	this()
	{
		ridx = 0;
		widx = 0;
	}

	@property public int readIndex() { return ridx; }
	@property public int writeIndex() { return widx; }

	public void set(int index,ubyte[])
	{

	}


	public void append(ubyte[] data)
	{
	}

	private void ensureWriteSpace(ubyte[] data)
	{

	}
}


unittest
{
	import gamelibd.util;
	
	writeFlush("hi");
	
}



