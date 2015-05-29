module gamelibd.MemPool;

import gamelibd.util;
import gamelibd.mem;

class MemPool
{
	private LinkedList!(ubyte[]) list = new LinkedList!(ubyte[])();
	private int blockSize;
	private int maxBlockNum;

	this(int blockSize,int maxBlockNum)
	{
		// Constructor code
		this.blockSize = blockSize;
		this.maxBlockNum = maxBlockNum;
	}

	public ubyte[] getBlock()
	{
		if(list.size<=0)
		{
			return mem.allocate(blockSize);
		}

		auto ret = list.removeHead();
		return ret;
	}

	public void returnBlock(ubyte[] block)
	{
		if(list.size>=maxBlockNum)
		{
			mem.dellocate(block);
			return;
		}

		list.addTail(block);
	}


	unittest
	{
		MemPool pool = new MemPool(10,5);
		assert(pool.list.size==0);

		auto b1 = pool.getBlock();
		assert (b1.length==10);
		assert(pool.list.size==0);

		auto b2 = pool.getBlock();
		assert (b2.length==10);
		assert(pool.list.size==0);

		auto b3 = pool.getBlock();
		assert (b3.length==10);
		assert(pool.list.size==0);


		auto b4 = pool.getBlock();
		assert (b4.length==10);
		assert(pool.list.size==0);


		auto b5 = pool.getBlock();
		assert (b5.length==10);
		assert(pool.list.size==0);

		auto b6 = pool.getBlock();
		assert (b6.length==10);
		assert(pool.list.size==0);


		pool.returnBlock(b1);
		assert(pool.list.size==1);

		pool.returnBlock(b2);
		assert(pool.list.size==2);

		pool.returnBlock(b3);
		assert(pool.list.size==3);

		pool.returnBlock(b4);
		assert(pool.list.size==4);

		pool.returnBlock(b5);
		assert(pool.list.size==5);

		pool.returnBlock(b6);
		assert(pool.list.size==5);



		b1 = pool.getBlock();
		assert(b1.length==10);
		assert(pool.list.size==4);

		pool.returnBlock(b1);
		assert(pool.list.size==5);
	}
}

