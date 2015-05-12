module gamelibd.net.linux.TcpLinuxConn;


version(linux)
{
	import core.stdc.errno;
	import gamelibd.exceptions;
	import gamelibd.net.linux.epollapi;
	import gamelibd.net.linux.IoEventHandler;
	import gamelibd.net.PosixApi;
	import gamelibd.net.provider;

	abstract class TcpLinuxConn :IoEventHandler, Conn
	{
		addrtransform localAddr;
		addrtransform remoteAddr;

		this(int sock,addrtransform localAddr,addrtransform remoteAddr)
		{
			this.sock = sock;
			epfd = ConnGlobals.epfd;
			this.localAddr = localAddr;
			this.remoteAddr = remoteAddr;
			debug writeFlush("new tcpconn");
		}

		override public void doRead(TEvent* evt) {
			tryResumeReaderFiber();
		}

		override public void doWrite(TEvent* evt) {
			tryResumeWriterFiber();
		}

		override public void doErr()
		{
			super.doErr();
			close();
		}

		override public void doEof()
		{
			super.doEof();
			close();
		}

		public string getRemoteIp()
		{
			return addrToIp(remoteAddr);
		}
		public ubyte[] getRemoteIpBytes()
		{
			return addrToIpBytes(remoteAddr);
		}
		public ushort getRemotePort()
		{
			return remoteAddr.addrin.sin_port;
		}

		public string getLocalIp()
		{
			return addrToIp(localAddr);
		}
		public ubyte[] getLocalIpBytes()
		{
			return addrToIpBytes(localAddr);
		}
		public ushort getLocalPort()
		{
			return localAddr.addrin.sin_port;
		}

		private void throwExceptionIfErrAfterOp(long bytes)
		{
			if(bytes< 0 && errno != EWOULDBLOCK)
			{
				err = true;
				throw new IoException("do io with sock failed.");
			}
		}

		protected void throwExceptionIfErr()
		{
			if(err)
			{
				throw new IoException("Unkown io error.");
			}
		}

		private bool setEofAfterOp(long bytes)
		{
			if(bytes == 0)
			{
				doEof();
			}
			return eof;
		}

		public int readSome(ubyte[] buf)
		{
			throwExceptionIfErr();
			//try read directly
			long bytes = 0;
			bytes = recv(sock, buf.ptr, cast(int)buf.length, 0);
			if(bytes>0)
			{
				//debug writeFlush("direct read");
				return cast(int)bytes;
			}
			if(setEofAfterOp(bytes))
			{
				return 0;
			}
			throwExceptionIfErrAfterOp(bytes);

			//try async read
			enableRead();
			scope (exit) disableRead();
			autoReaderFiberSetting((){
					throwExceptionIfErr();

					bytes = recv(sock, buf.ptr, cast(int)buf.length, 0);
					setEofAfterOp(bytes);
					throwExceptionIfErrAfterOp(bytes);

					//debug writeFlush("after read ,fiber ",ExceptionSafeFiber.getThis().name,",sock ",sock," - ",cast(void*)this);
				});

			return cast(int)bytes;
		}

		public int writeSome(ubyte[] buf)
		{
			throwExceptionIfErr();
			//try write directly
			long bytes = 0;
			bytes = send(sock,cast(const void *)(buf.ptr),buf.length,0);
			if(bytes>0)
			{
				//debug writeFlush("direct write");
				return cast(int)bytes;
			}
			throwExceptionIfErrAfterOp(bytes);

			//try async write
			enableWrite();
			scope (exit) disableWrite();
			autoWriterFiberSetting((){
					//debug writeFlush("resume write ,fiber ",ExceptionSafeFiber.getThis().name,",sock ",sock," - ",cast(void*)this);
					throwExceptionIfErr();

					bytes = send(sock,cast(const void *)(buf.ptr),buf.length,0);
					throwExceptionIfErrAfterOp(bytes);
					
					//debug writeFlush("after write ,fiber ",ExceptionSafeFiber.getThis().name,",sock ",sock," - ",cast(void*)this);
				});

			return cast(int)bytes;
		}

		public int read(ubyte[] buf)
		{
			int offset = 0;
			while(offset<buf.length)
			{
				int n = readSome(buf[offset..$]);
				if(n>0)
				{
					offset += n;
				}
				if(eof)
				{
					break;
				}
			}
			return offset;
		}

		public int write(ubyte[] buf)
		{
			int offset = 0;
			while(offset<buf.length)
			{
				int n = writeSome(buf[offset..$]);

				if(n>0)
				{
					offset += n;
				}
			}
			return offset;
		}

		public int readUtil(ubyte[] buf,string endflag)
		{
			int offset = 0;
			bool found = false;
			while(offset<buf.length)
			{
				int n = readSome(buf[offset..$]);
				import std.algorithm;
				if(n>0)
				{
					offset += n;
				}
				found = (find(endflag,buf[0..offset])!=[]);
				if(found)
				{
					return offset;
				}
			}
			throw new IoException("endflag not found until eof");
		}
	
		public int getHandle()
		{
			return sock;
		}

		public  bool isEof() {
			return eof;
		}

		void close()
		{
			if(sock>0)
			{
				closeFd(sock);
				sock = -1;

				tryResumeReaderFiber();
				tryResumeWriterFiber();

				debug writeFlush("TcpConn closed");
			}
		}
	}

}