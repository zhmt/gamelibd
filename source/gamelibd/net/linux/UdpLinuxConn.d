module gamelibd.net.linux.UdpLinuxConn;

version(linux)
{
	import core.stdc.errno;

	import gamelibd.net.linux.IoEventHandler;
	import gamelibd.net.linux.epollapi;
	import gamelibd.net.provider;
	import gamelibd.net.PosixApi;
	import gamelibd.exceptions;

	class UdpLinuxConn : IoEventHandler,UdpConn
	{
		this(int sock)
		{
			this.sock = sock;
			epfd = ConnGlobals.epfd;
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
				eof = true;
			}
			return eof;
		}

		public int read(ref addrtransform addr,ubyte[] buf)
		{
			throwExceptionIfErr();
			//try read directly
			long bytes = 0;
			uint addrlen = addrtransform.sizeof;
			bytes = recvfrom(sock, cast(void*)buf.ptr, cast(int)buf.length, 0, &addr.addr, &addrlen);
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
					
					bytes = recvfrom(sock, cast(void*)buf.ptr, cast(int)buf.length, 0, &addr.addr, &addrlen);
					setEofAfterOp(bytes);
					throwExceptionIfErrAfterOp(bytes);
					
					debug writeFlush("after read ,fiber ",ExceptionSafeFiber.getThis().name,",sock ",sock," - ",cast(void*)this);
				});
			
			return cast(int)bytes;
		}

		public int writeTo(ref addrtransform addr,ubyte[] buf)
		{
			throwExceptionIfErr();
			//try write directly
			long bytes = 0;
			bytes = sendto(sock,cast(const void *)(buf.ptr),buf.length,0,&addr.addr,addrtransform.sizeof);
			if(bytes>0)
			{
				debug writeFlush("direct write");
				return cast(int)bytes;
			}
			throwExceptionIfErrAfterOp(bytes);
			
			//try async write
			enableWrite();
			scope (exit) disableWrite();
			autoWriterFiberSetting((){
					debug writeFlush("resume write ,fiber ",ExceptionSafeFiber.getThis().name,",sock ",sock," - ",cast(void*)this);
					throwExceptionIfErr();
					
					bytes = sendto(sock,cast(const void *)(buf.ptr),buf.length,0,&addr.addr,addrtransform.sizeof);
					throwExceptionIfErrAfterOp(bytes);
					
					debug writeFlush("after write ,fiber ",ExceptionSafeFiber.getThis().name,",sock ",sock," - ",cast(void*)this);
				});
			
			return cast(int)bytes;
		}
		
		public void close()
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
		
		public int getHandle()
		{
			return sock;
		}

	}



}