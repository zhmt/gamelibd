module gamelibd.Buf;

import gamelibd.net.conn;
import gamelibd.util;
import gamelibd.MemPool;
import gamelibd.exceptions;
import std.exception:enforce;

/** An buffer that could automatically extend or shrink */
class Buf
{
	private ubyte[][] sink;
	private long ridx;
	private long rbidx;
	private long widx;
	private long wbidx;
	private long sinkCap;
	private long lastBlokIndex;

	this()
	{
		reinit();
	}

	@property public long readIndex() { return ridx; }
	@property public void readIndex(long index) {
		this.ridx=index; 
		this.rbidx = ridx/MemPool.poolOneK.blockSize;
	}
	@property public long writeIndex() { return widx; }
	@property public void writeIndex(long index){
		this.widx=index; 
		this.wbidx = widx/MemPool.poolOneK.blockSize; 
	}

	private void reinit()
	{
		sink = new ubyte[][32];
		ridx = 0;
		widx = 0;
		rbidx = 0;
		wbidx = 0;
		sinkCap = 0;
		lastBlokIndex = 0;
	}

	public void set(long index,ubyte[] data)
	{
		if(data is null) return;

		ensureWriteSpace(data.length,index);
		copyArrIn(data,index/MemPool.poolOneK.blockSize,index);
	}

	public void set(long index,ubyte data)
	{
		ensureWriteSpace(1,index);

		sink[index/MemPool.poolOneK.blockSize][index%MemPool.poolOneK.blockSize] = data;
	}

	public ubyte get(long index)
	{
		enforce!IndexOutOfBoundException(index<widx);
		return sink[index/MemPool.poolOneK.blockSize][index%MemPool.poolOneK.blockSize];
	}

	public void compress()
	{
	}

	public void release()
	{
		freeBlocks();
		reinit();
	}

	private void freeBlocks()
	{
		for(int i=0; i<sink.length; i++)
		{
			ubyte[] arr = sink[i];
			if(arr!=null)
			{
				MemPool.poolOneK.returnBlock(arr);
				sink[i] = null;
			}else{
				break;
			}
		}
	}


	public void append(ubyte data)
	{
		ensureWriteSpace(1,widx);
		sink[wbidx][widx%MemPool.poolOneK.blockSize] = data;
		widx++;
		if(widx%MemPool.poolOneK.blockSize==0)
		{
			wbidx++;
		}
	}

	public void append(ubyte[] data)
	{
		if(data is null)
		{
			return;
		}
		ensureWriteSpace(data.length,widx);
		copyArrIn(data,wbidx,widx);
		widx += data.length;
		wbidx = widx/MemPool.poolOneK.blockSize;
	}

	private void copyArrIn(ubyte[] data,long bidx,long idx)
	{
		long toCopy = data.length;
		long dataOffset = 0;
		ubyte[] block;
		long blocksize = 0;
		long blockOffset;
		while(toCopy>0)
		{
			block = sink[bidx];
			enforce!NullPointerException(block !is null);
			blockOffset = idx%block.length;
			blocksize = block.length - blockOffset;

			if(blocksize>=toCopy)
			{
				block[blockOffset..blockOffset+toCopy] = data[dataOffset..$];
				toCopy -= toCopy;
				break;
			} else 
			{
				block[blockOffset..blockOffset+blocksize] = data[dataOffset..dataOffset+blocksize];
				toCopy -= blocksize;
				dataOffset +=  blocksize;
				idx += blocksize;
				bidx++;
			}
		}

	}

	private void ensureWriteSpace(long space,long startIdx)
	{
		long needMore = space - (sinkCap-startIdx);
	//writeFlush(needMore,",",sinkCap,",",startIdx);
		while(needMore>0)
		{
			if(lastBlokIndex==sink.length)
			{
				sink.length = sink.length * 2;
			}

			ubyte[] block = MemPool.poolOneK.getBlock();
			sink[lastBlokIndex++] = block;
			sinkCap += block.length;
			needMore -= block.length;
		}
	}
}


unittest
{
	void testAppend()
	{
		Buf buf = new Buf;
		ubyte[] hi = [1,2];
		buf.append(hi);
		assert(buf.get(0)==1);
		assert(buf.get(1)==2);
		buf.release();
	}

	void testMultiBlockAppend(long N)
	{
		Buf buf = new Buf;
		ubyte[] bytes =  [1,2,3,4,5,6,7,8,9,10,11,12,13]; 
		N = N/bytes.length;
		int mod = 256;

		for(int i=0; i<N;i++)
		{
			buf.append(bytes);
		}
		for(int i=0; i<N;i++)
		{
			for(int ii=0; ii<bytes.length; ii++)
			{
				assert(buf.get(i*bytes.length+ii)==bytes[ii]);
			}
		}

		buf.release();
	}

	void testAppendByte(int N)
	{
		Buf buf = new Buf;
		int mod = 256;
		for(int i=0; i<N;i++)
		{
			buf.append(cast(ubyte)(i%mod));
		}
		for(int i=0; i<N; i++)
		{
			//writeFlush(i,",",buf.get(i),",",i%mod);
			assert(buf.get(i) == i%mod);
		}
		buf.release();
	}

	void testBigMem(int n)
	{
		testAppendByte(n);
	}

	void testSet(long N)
	{
		Buf buf = new Buf;
		ubyte[] bytes =  [1,2,3,4,5,6,7,8,9,10,11,12,13]; 
		N = N/bytes.length;
		int mod = 256;
		
		for(int i=0; i<N;i++)
		{
			buf.set(i*bytes.length,bytes);
		}
		buf.writeIndex = N*bytes.length;

		for(int i=0; i<N;i++)
		{
			for(int ii=0; ii<bytes.length; ii++)
			{
				assert(buf.get(i*bytes.length+ii)==bytes[ii]);
			}
		}

		
		buf.release();
	}

	void testSetByte(long N)
	{
		Buf buf = new Buf;
		int mod = 256;
		
		for(int i=0; i<N;i++)
		{
			buf.set(i,cast(ubyte)(i%mod));
		}
		buf.writeIndex = N;
		
		for(int i=0; i<N;i++)
		{
			assert(buf.get(i) == i%mod);
		}
		
		
		buf.release();
	}

	testAppend();
	testMultiBlockAppend(4*MemPool.poolOneK.blockSize);
	testMultiBlockAppend(1*1024*1024);
	testAppendByte(4*MemPool.poolOneK.blockSize);
	testBigMem(1*1024*1024); //1M
	testSet(4*MemPool.poolOneK.blockSize);
	testSet(1*1024*1024);
	testSetByte(4*MemPool.poolOneK.blockSize);
	testSetByte(1*1024*1024);
}



