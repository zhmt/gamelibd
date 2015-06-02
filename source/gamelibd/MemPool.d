module gamelibd.MemPool;

import gamelibd.util;
import gamelibd.mem;
import std.exception:enforce;

class MemPool
{
	__gshared static MemPool poolOneK ;

	private LinkedList!(ubyte[]) list;
	private int _blockSize;
	private int maxBlockNum;

	static this()
	{
		poolOneK = new MemPool(1024,30*1024*1024/(1024));
	}

	this(int blockSize,int maxBlockNum)
	{
		this._blockSize = blockSize;
		this.maxBlockNum = maxBlockNum;
		list = new LinkedList!(ubyte[])();
	}

	public ubyte[] getBlock()
	{
		if(list.size<=0)
		{
			//writeFlush("new buff");
			return mem.allocate(_blockSize);
		}

		auto ret = list.removeHead();
		//writeFlush("get from buf");
		return ret;
	}

	public void returnBlock(ubyte[] block)
	{
		enforce(block.length==_blockSize,"size fo block to be recycled is mismatched.");

		if(list.size>=maxBlockNum)
		{
			//writeFlush("free buff");
			mem.dellocate(block);
			return;
		}
		//writeFlush("retturn");
		list.addTail(block);
	}

	public @property int blockSize()
	{
		return _blockSize;
	}
}

unittest
{

	void test(){
		auto b100 = MemPool.poolOneK.getBlock();
		assert(b100.length == (1024));
		MemPool.poolOneK.returnBlock(b100);
		
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

	test();
	
}