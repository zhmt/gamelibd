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
	private long widx;
	private long sinkCap;
	private long lastBlokIndex;

	this()
	{
		reinit();
	}

	@property public long readIndex() { return ridx; }
	@property public void readIndex(long index) { this.ridx=index; }
	@property public long writeIndex() { return widx; }
	@property public void writeIndex(long index){ this.widx=index; }
	public void skipRead(long count) 
	{ 
		enforce!IndexOutOfBoundException(widx-ridx>=count);
		ridx+=count; 
	}
	public void skipWrite(long count) 
	{
		ensureWriteSpace(count,widx);
		widx += count;
	}

	public void writeTo(Ptr!Conn conn,long num)
	{
		enforce!IndexOutOfBoundException(num<=readAvailable);
		long idx = ridx;
		ubyte[] block ;
		long blockOffset;
		while(num>0)
		{
			blockOffset = idx%MemPool.poolOneK.blockSize;
			if(MemPool.poolOneK.blockSize-blockOffset>num)
			{
				block = sink[idx/MemPool.poolOneK.blockSize][blockOffset..blockOffset+num];
			}else
			{
				block = sink[idx/MemPool.poolOneK.blockSize][blockOffset..$];
			}
			conn.write(block);
			idx += block.length;
			num -= block.length;
		}
		skipRead(num);
	}

	public void readSomeFrom(Ptr!Conn conn)
	{
		ensureWriteSpace(1,widx);
		ubyte[] block = sink[widx/MemPool.poolOneK.blockSize][widx%MemPool.poolOneK.blockSize..$];
		int n = conn.readSome(block);
		if(n>0)
		{
			skipWrite(n);
		}
	}

	private void reinit()
	{
		sink = new ubyte[][32];
		ridx = 0;
		widx = 0;
		sinkCap = 0;
		lastBlokIndex = 0;
	}

	public void set(long index,ubyte data)
	{
		ensureWriteSpace(1,index);
		sink[index/MemPool.poolOneK.blockSize][index%MemPool.poolOneK.blockSize] = data;
	}

	/** add data to tail,and move writeIndex forward  */
	public void append(ubyte data)
	{
		set(widx,data);
		widx++;
	}

	/** change data in buf,but dont move writeIndex */
	public void set(long index,ubyte[] data)
	{
		enforce!NullPointerException(data !is null);
		ensureWriteSpace(data.length,index);
		copyArrIn(data,index/MemPool.poolOneK.blockSize,index);
	}
	
	public void append(ubyte[] data)
	{
		set(widx,data);
		widx += data.length;
	}

	public ubyte get(long index)
	{
		enforce!IndexOutOfBoundException(index<widx);
		return sink[index/MemPool.poolOneK.blockSize][index%MemPool.poolOneK.blockSize];
	}

	/** read a byte from buf and move readIndex forward  */
	public ubyte read()
	{
		ubyte ret = get(ridx);
		ridx++;
		return ret;
	}

	/** copy data into buf */
	public void get(long index,ubyte[] buf)
	{
		enforce!NullPointerException(buf !is null);
		enforce!IndexOutOfBoundException(widx-index>=buf.length);
		copyOut(buf,index/MemPool.poolOneK.blockSize,index);
	}

	public void read(ubyte[] buf)
	{
		get(ridx,buf);
		ridx += buf.length;
	}

	/** Drop data that has been read, and release memory ocupied by them. 
	This could make readIndex and writeIndex change.
	  */
	public void compact()
	{
		long rbidx = ridx/MemPool.poolOneK.blockSize;
		if(ridx==widx)
		{
			release();
			return;
		}

		if(rbidx>0)
		{
			//release 
			for(int i=0; i<rbidx; i++)
			{
				MemPool.poolOneK.returnBlock(sink[i]);
			}
			//move
			for(long i=rbidx; i<sink.length; i++)
			{
				sink[i-rbidx] = sink[i];
				sink[i] = null;
			}

			long offset = MemPool.poolOneK.blockSize*rbidx;
			sinkCap -= offset;
			lastBlokIndex-=rbidx;
			ridx -= offset;
			widx -= offset;
		}
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

	/** how much data can i read from buffer now */
	public @property long readAvailable()
	{
		return widx - ridx;
	}

	private void copyOut(ubyte[] buf,long bidx,long idx)
	{
		long toCopy = buf.length;
		long buffOffset = 0;
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
				buf[buffOffset..$] = block[blockOffset..blockOffset+toCopy];
				toCopy -= toCopy;
				break;
			}else
			{
				buf[buffOffset..buffOffset+blocksize] = block[blockOffset..$];
				toCopy -= blocksize;
				buffOffset += blocksize;
				idx += blocksize;
				bidx ++;
			}
		}
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
				block[blockOffset..$] = data[dataOffset..dataOffset+blocksize];
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
				sink.length = sink.length * 2;

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

	void testRead(int N)
	{
		Buf buf = new Buf;
		int mod = 256;
		for(int i=0; i<N;i++)
		{
			buf.append(cast(ubyte)(i%mod));
			assert(buf.readAvailable==i+1);
		}
		for(int i=0; i<N; i++)
		{
			//writeFlush(i,",",buf.get(i),",",i%mod);
			assert(buf.read() == i%mod);
			assert(buf.readAvailable==N-i-1);
		}
		assert(buf.readAvailable==0);
		buf.release();
	}

	void testGetArr(long N)
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
			ubyte[] tmp = new ubyte[bytes.length];
			buf.get(i*bytes.length,tmp);
			for(int ii=0; ii<bytes.length; ii++)
			{
				assert(tmp[ii]==bytes[ii]);
			}
		}
		
		buf.release();
	}

	void testReadArr(long N)
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
			ubyte[] tmp = new ubyte[bytes.length];
			buf.read(tmp);
			for(int ii=0; ii<bytes.length; ii++)
			{
				assert(tmp[ii]==bytes[ii]);
			}
		}
		
		buf.release();
	}

	void testCompact(long N)
	{
		Buf buf = new Buf;
		int mod = 256;
		
		for(int i=0; i<N;i++)
		{
			buf.append(cast(byte)(i%mod));
		}

		buf.compact();

		long cap = buf.sinkCap;
		
		for(int i=0; i<N;i++)
		{
			assert(buf.read()==i%mod);
			if(i%MemPool.poolOneK.blockSize==0)
			{
				buf.compact();
				assert(buf.sinkCap == cap-i);

			}
		}

		buf.compact();

		assert(buf.sinkCap==0);
		
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

	testGetArr(1*1024*1024);

	testRead(1*1024*1024);
	testReadArr(1*1024*1024);

	testCompact(1*1024*1024);
}



