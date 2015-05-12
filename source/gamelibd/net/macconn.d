module gamelibd.net.macconn;

import gamelibd.mem;
import gamelibd.util;
import gamelibd.net.provider;
import gamelibd.net.exceptionsafefiber;

import std.stdio;
import std.string;
import std.traits;
import std.exception : enforce;



import gamelibd.net.PosixApi;

//=========================system api
version(OSX)
{
	alias ushort u_short;
	alias uint u_int;
	alias ulong uint64_t;
	
	
	enum{
		/* actions */
		EV_ADD=		0x0001,		/* add event to kq (implies enable) */
		EV_DELETE=	0x0002,		/* delete event from kq */
		EV_ENABLE=	0x0004,		/* enable event */
		EV_DISABLE=	0x0008,		/* disable event (not reported) */
		EV_RECEIPT=	0x0040,		/* force EV_ERROR on success, data == 0 */
		
		/* returned values */
		EV_EOF=		0x8000,		/* EOF detected */
		EV_ERROR=	0x4000,		/* error, data contains errno */


		EVFILT_READ=		(-1),
		EVFILT_WRITE=		(-2),
		EVFILT_AIO=			(-3),	/* attached to aio requests */
		EVFILT_VNODE=		(-4),	/* attached to vnodes */
		EVFILT_PROC=		(-5),	/* attached to struct proc */
		EVFILT_SIGNAL=		(-6),	/* attached to struct proc */
		EVFILT_TIMER=		(-7),	/* timers */
		EVFILT_MACHPORT=    (-8),	/* Mach portsets */
		EVFILT_FS=			(-9),	/* Filesystem events */
		EVFILT_USER=        (-10),   /* User events */
		/* (-11) unused */
		EVFILT_VM=			(-12)	/* Virtual memory events */
	}
	
	
	struct timespec {
		time_t tv_sec;        /* seconds */
		long   tv_nsec;       /* and nanoseconds */
	};

	struct kevent_s { 
		c_long 		ident;      /* event ID */ 
		short     	filter;    	/* 事件过滤器 */ 
		u_short   	flags;      /* 行为标识 */ 
		u_int     	fflags;     /* 过滤器标识值 */ 
		c_long  	data;       /* 过滤器数据 */ 
		void*		udata;      /* 应用透传数据 */ 
	}; 


extern(C):

	int kqueue();
	
	int kevent(int kq, const kevent_s *changelist, int nchanges, 
		kevent_s *eventlist, int nevents, 
		const timespec *timeout);
}


//=========================custome api

version(OSX)
{


	void evset(ref kevent_s evt,c_long ident,short filter,u_short flags,uint fflags,c_long data,void *udata)
	{
		evt.ident = ident;
		evt.filter = filter;
		evt.flags = flags;
		evt.fflags = fflags;
		evt.data = data;
		evt.udata = udata;
	}
	


	void register(int kq, int fd,void* userData,bool r,bool w)
	{
		kevent_s[2] changes;
		evset(changes[0], fd, EVFILT_READ, EV_ADD|(r?EV_ENABLE:EV_DISABLE), 0, 0, userData);
		evset(changes[1], fd, EVFILT_WRITE, EV_ADD|(w?EV_ENABLE:EV_DISABLE), 0, 0, userData);
		
		int ret = kevent(kq, cast(const kevent_s *)&changes[0], changes.length, null, 0, null);
		enforce (ret != -1,new StdioException("Register event failed."));
	}

	void changeIntrest(int kq, int fd,void* userData,short filter,bool enable)
	{
		kevent_s[1] changes;
		evset(changes[0], fd, filter, enable?EV_ENABLE:EV_DISABLE, 0, 0, userData);
		
		int ret = kevent(kq, cast(const kevent_s *)&changes[0], changes.length, null, 0, null);
		enforce (ret != -1,new StdioException("Register event failed."));
	}
	

	
	void handleEvent(int kq, kevent_s* events, int nevents)
	{
		for (int i = 0; i < nevents; i++)
		{
			try{
				debug writeFlush("handle event, udata:" ,events[i].udata);

				Fd handler = cast(Fd ) events[i].udata;

				if((events[i].flags & EV_ERROR) != 0)
				{
					debug writeFlush("err branch");
					handler.err = true;
					handler.doNetErr();
					continue;
				}

				if((events[i].flags & EV_EOF) != 0)
				{
					debug writeFlush("eof branch ," ,handler.readerFiber.internal,", ",handler.writerFiber.internal,", ",handler);
					handler.eof = true;
					handler.doEof(&events[i]);
					continue;
				}

				if (events[i].filter == EVFILT_READ && handler.readerFiber.isNotNull)
				{
					debug writeFlush("read branch");
					handler.doRead(&events[i]);
					continue;
				}else if(events[i].filter == EVFILT_WRITE && handler.writerFiber.isNotNull)
				{
					debug writeFlush("write branch");
					handler.doWrite(&events[i]);
					continue;
				}else 
				{
					debug writeFlush("unknown branch");
					handler.doNetErr();
					continue;
				}
			}catch(Throwable t)
			{
				writeFlush("unkown exception : ",t.msg,"\r\n",t.info);
			}
		}
	}


	class Fd
	{
		public static __gshared const int kq;

		static this() { kq = kqueue(); }


		import core.thread;

		int sock;
		bool rintrest;
		bool wintrest;
		bool eof;
		bool err;
		Ptr!ExceptionSafeFiber readerFiber;
		Ptr!ExceptionSafeFiber writerFiber;

		public void registerDisableWrite()
		{
			register(kq,sock,cast(void*)this,true,false);
			this.rintrest = true;
			this.wintrest = false;
		}

		void registerDisableRead()
		{
			register(kq,sock,cast(void *)this,false,true);
			this.rintrest = false;
			this.wintrest = true;
		}
		
		void registerDisable()
		{
			register(kq,sock,cast(void *)this,false,false);
			this.rintrest = false;
			this.wintrest = false;
		}
		
		void enableRead()
		{
			if(rintrest)
			{
				return;
			}
			changeIntrest(kq,sock,cast(void *)this,EVFILT_READ,true);
			this.rintrest = true;
		}
		
		void disableRead()
		{
			if(!rintrest)
			{
				return;
			}
			changeIntrest(kq,sock,cast(void *)this,EVFILT_READ,false);
			this.rintrest = false;
		}
		
		void enableWrite()
		{
			if(wintrest)
			{
				return;
			}
			changeIntrest(kq,sock,cast(void *)this,EVFILT_WRITE,true);
			this.wintrest = true;
		}
		
		void disableWrite()
		{
			if(!this.wintrest)
			{
				return;
			}
			changeIntrest(kq,sock,cast(void *)this,EVFILT_WRITE,false);
			this.wintrest = false;
		}

		public void doRead(kevent_s* evt)
		{
			writeFlush("calling blank doRead");
		}

		public void doWrite(kevent_s* evt)
		{
			writeFlush("calling blank doWrite");
		}

		public void close()
		{
		}

		public void doNetErr()
		{
			this.err = true;
			tryResumeReaderFiber();
			tryResumeWriterFiber();
		}

		public void doEof(kevent_s* evt)
		{

		}

		public void tryResumeReaderFiber()
		{
			if(readerFiber.isNull)
			{
				try
				{
					disableRead();
				}catch(Throwable t)
				{
					writeFlush(t.msg);
				}
			}else
			{
				readerFiber.resume();
			}
		}
		
		public void tryResumeWriterFiber()
		{
			if(writerFiber.isNull)
			{
				try
				{
					disableWrite();
				}catch(Throwable t)
				{
					writeFlush(t.msg);
				}
			}else
			{
				writerFiber.resume();
			}
		}
	}

	class Acc : Fd,ProviderAcceptor
	{
		class PendingSock
		{
			int newsock;
			addrtransform newaddr;
		}

		import core.thread;
		public
		{	
			int newsock;
			addrtransform newaddr;
			LinkedList!PendingSock pending;
		}

		public this(string ip,ushort port,int backlog)
		{
			pending = new LinkedList!PendingSock;
			sock = createTcpListener(ip,port,backlog);
			registerDisableWrite();
		}

		public ~this()
		{
			close();
			debug writeFlush("close acceptor");
		}
		
		override public void close()
		{
			import core.sys.posix.unistd;
			if(sock>0) 
			{
				close(sock);
				sock = -1;
			}
		}

		public Conn accept()
		{
			if(pending.isEmpty())
			{
				scope(exit) readerFiber = null;
				readerFiber = ExceptionSafeFiber.getThis();
				enforce(readerFiber !is null,new StdioException("Conn.accept must be called in Fiber."));

				ExceptionSafeFiber.yield();
			}else
			{
				PendingSock penddingSock = pending.removeHead();
				newsock = penddingSock.newsock;
				newaddr = penddingSock.newaddr;
			}

			debug writeFlush("newsock :",newsock);
			import core.sys.posix.unistd;
			scope(failure) close(newsock);
			ServerMacConn ret = new ServerMacConn(newsock);
			scope(failure) ret.close();
			ret.remote = newaddr;
			uint size = sockaddr.sizeof;
			int suc = getsockname(newsock,&ret.local.addr,&size);
			enforce(suc != -1,new StdioException("accept failed."));
			return ret;
		}

		public string getIp()
		{
			return null;
		}

		public ushort getPort()
		{
			return 0;
		}

		override public void doEof(kevent_s* evt) {

		}

		override void doRead(kevent_s* evt)
		{
			doAccept(evt);
		}

		private void doAccept( kevent_s* evt)
		{
			int connSize = cast(int)evt.data;
			int listener = cast(int)evt.ident;
			Acc acc = cast(Acc) (cast (void*)evt.udata);
			
			debug writeFlush("accepted. connSize ",connSize);
			
			for (int i = 0; i < connSize; i++)
			{
				addrtransform addr;
				uint len = addrtransform.sizeof;

				import core.sys.posix.sys.socket;
				int client = accept(listener, cast(sockaddr*)&addr, &len);
				if (client == -1)
				{
					writeFlush( "Accept failed.");
					continue;
				}

				import core.sys.posix.unistd;
				scope(failure) close(client);
				acc.newsock = client;
				acc.newaddr = addr;
				setNonBlock(client);

				if(connSize>1 && i<connSize-1)
				{
					PendingSock tmp = new PendingSock;
					tmp.newsock = client;
					tmp.newaddr = addr;
					pending.addTail(tmp);
				}
			}

			acc.tryResumeReaderFiber();
		}

	}

	class MacConn : Fd,Conn
	{
		import core.thread;
		public
		{
			int readAvailBytes;
			int writeAvailBytes;
			addrtransform local;
			addrtransform remote;
		}

		override public void doEof(kevent_s* evt)
		{
			doRead(evt);
			doWrite(evt);
		}

		public NetRs readSome(ubyte[] buf)
		{
			scope(exit) readerFiber = null;
			NetRs rs;
			if(eof)
			{
				disableRead();
				rs.eof = true;
				return rs;
			}

			debug writeFlush("befor read ,fiber ",ExceptionSafeFiber.getThis().name,",sock ",sock," - ",cast(void*)this);

			readerFiber = ExceptionSafeFiber.getThis();
			enforce(readerFiber !is null,new StdioException("Conn.readSome must be called in Fiber."));

			enableRead();
			ExceptionSafeFiber.yield();

			if(err)
			{
				disableRead();
				throw new StdioException("Unkown io error.");
			}

			long toRead = readAvailBytes<buf.length?readAvailBytes:buf.length;
			long bytes = recv(sock, buf.ptr, toRead, 0);
			disableRead();
			enforce (bytes != -1,new StdioException("Read from sock failed."));

			rs.eof = eof;
			rs.bytes = cast(int)bytes;

			debug writeFlush("after read ,fiber ",ExceptionSafeFiber.getThis().name,",sock ",sock," - ",cast(void*)this);
			
			return rs;
		}

		public NetRs writeSome(ubyte[] buf)
		{
			scope(exit) writerFiber = null;
			NetRs rs;

			debug writeFlush("befor write ,fiber ",ExceptionSafeFiber.getThis().name,",sock ",sock," - ",cast(void*)this);

			writerFiber = ExceptionSafeFiber.getThis();
			enforce(writerFiber !is null,new StdioException("Conn.writeSome must be called in Fiber."));

			enableWrite();
			ExceptionSafeFiber.yield();
			debug writeFlush("resume write ,fiber ",ExceptionSafeFiber.getThis().name,",sock ",sock," - ",cast(void*)this);

			if(err)
			{
				disableWrite();
				throw new StdioException("Unkown io error.");
			}

			long towrite = writeAvailBytes<buf.length?writeAvailBytes:buf.length;
			long bytes = send(sock,cast(const void *)(buf.ptr),towrite,0);
			disableWrite();
			enforce (bytes != 0 && bytes != -1,new StdioException("Write to sock failed."));

			debug writeFlush("after write ,fiber ",ExceptionSafeFiber.getThis().name,",sock ",sock," - ",cast(void*)this);
			rs.bytes = cast(int)bytes;
			return rs;
		}



		public NetRs read(ubyte[] buf)
		{
			NetRs rs ;
			int offset = 0;
			while(offset<buf.length)
			{
				NetRs n = readSome(buf[offset..$]);
				if(n.bytes>0)
				{
					offset += n.bytes;
				}
				if(n.eof)
				{
					rs.eof = true;
					break;
				}
			}
			return rs;
		}

		public NetRs write(ubyte[] buf)
		{
			NetRs rs;
			int offset = 0;
			while(offset<buf.length)
			{
				NetRs n = writeSome(buf[offset..$]);
				if(n.bytes>0)
				{
					offset += n.bytes;
				}
				if(n.eof)
				{
					rs.eof = true;
					break;
				}
			}
			rs.bytes=offset;
			return rs;
		}

		public NetRs readUtil(ubyte[] buf,string endflag) {
			NetRs rs;
			int offset = 0;
			while(offset<buf.length)
			{
				NetRs n = readSome(buf[offset..$]);
				import std.algorithm;
				if(n.bytes>0)
				{
					offset += n.bytes;
				}
				bool found = (find(endflag,buf[0..offset])!=[]);
				if(found || n.eof)
				{
					rs.bytes = offset;
					rs.eof = n.eof;
					if(!found)
					{
						rs.status = -1;
					}
					break;
				}
			}
			return rs;
		}

		private static string addrToIp(ref addrtransform addr)
		{
			ubyte[4] ip = (cast(ubyte*)&addr.addrin.sin_addr.s_addr)[0 .. 4];
			return format("%d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3]);
		}

		public ubyte[] getRemoteIpBytes()
		{
			import std.bitmanip;
			return std.bitmanip.nativeToBigEndian!(uint)(cast(uint)remote.addrin.sin_addr.s_addr);
		}

		public ubyte[] getLocalIpBytes()
		{
			import std.bitmanip;
			return std.bitmanip.nativeToBigEndian!(uint)(cast(uint)local.addrin.sin_addr.s_addr);
		}

		public string getRemoteIp()
		{
			return addrToIp(remote);
		}
		public ushort getRemotePort()
		{
			return remote.addrin.sin_port;
		}
		public string getLocalIp()
		{
			return addrToIp(local);
		}
		public ushort getLocalPort()
		{
			return local.addrin.sin_port;
		}

		public int getHandle()
		{
			return sock;
		}

		override public void close()
		{
		}
	}

	class ServerMacConn : MacConn
	{
		public this(int sock)
		{
			this.sock = sock;
			registerDisable();
		}
		
		public ~this()
		{
			close();
		}

		override public void close()
		{
			import core.sys.posix.unistd;
			if(sock>0) 
			{
				debug writeFlush("close conn");
				close(sock);
				sock = -1;
			}
		}

		override public void doRead(kevent_s* evt)
		{
			readAvailBytes = cast(int)evt.data;
			tryResumeReaderFiber();
		}
		
		override public void doWrite(kevent_s* evt)
		{
			writeAvailBytes = cast(int)evt.data;
			tryResumeWriterFiber();
		}


	}

	class ClientMacConn : MacConn
	{
		public bool connected = false;

		int readAvailBytes;
		int writeAvailBytes;
		addrtransform local;
		addrtransform remote;

		public this(int sock)
		{
			this.sock = sock;
		}
		
		public ~this()
		{
			close();
		}

		override public void close()
		{
			import core.sys.posix.unistd;
			if(sock>0) 
			{
				close(sock);
				debug writeFlush("close conn");
				sock = -1;
			}
		}
		
		override public void doRead(kevent_s* evt)
		{
			if(connected)
			{
				readAvailBytes = cast(int)evt.data;
				tryResumeReaderFiber();

			}else
			{
				tryResumeWriterFiber();
			}
		}
		
		override public void doWrite(kevent_s* evt)
		{
			if(connected) 
			{
				writeAvailBytes = cast(int)evt.data;
				tryResumeWriterFiber();
			}else
			{
				tryResumeWriterFiber();
			}
		}

		void connect(string ip,ushort port)
		{
			import core.sys.posix.sys.socket;
			import core.stdc.string : memcpy;
			import core.stdc.errno;

			addrtransform tran;
			tran.addrin.sin_family = AF_INET;
			tran.addrin.sin_port = htons(port);
			auto h = gethostbyname(ip.toStringz());
			memcpy(&tran.addrin.sin_addr.s_addr, h.h_addr, h.h_length);
			
			int rs = connect(sock, cast(sockaddr*) &tran, addrtransform.sizeof);
			enforce(rs ==-1 && errno==EINPROGRESS,new StdioException(format("Connect failed : %s:%s",ip,port)));

			if(rs==0)
			{
				connected = true;
				uint addrlen = sockaddr.sizeof;
				getsockname(sock,&local.addr,&addrlen);
				remote = tran;
				registerDisable();
			}else
			{
				scope(exit) writerFiber = null;
				writerFiber = ExceptionSafeFiber.getThis();

				enforce(writerFiber !is null,new StdioException("Conn.connect must be called in Fiber."));
				registerDisableRead();

				ExceptionSafeFiber.yield();
				disableWrite();
				if(!err && !eof)
				{
					connected = true;
				}else
				{
					throw new StdioException(format("Connect failed : %s:%s",ip,port));
				}

			}
		}
	}


//	class MacUdpConn : Fd,UdpConn
//	{
//		public bool connected ;
//		public this(int sock)
//		{
//			this.sock = sock;
//		}
//		
//		public ~this()
//		{
//			close();
//		}
//
//		//=========================methods from FD
//
//		override public void doRead(kevent_s* evt)
//		{
//			readAvailBytes = cast(int)evt.data;
//			tryResumeReaderFiber();
//		}
//		
//		override public void doWrite(kevent_s* evt)
//		{
//			writeAvailBytes = cast(int)evt.data;
//			tryResumeWriterFiber();
//		}
//
//		override public void close()
//		{
//			import core.sys.posix.unistd;
//			if(sock>0) 
//			{
//				close(sock);
//				debug writeFlush("close conn");
//				sock = -1;
//			}
//		}
//
//		//=========================methods from UdpConn
//
//		public NetRs read(ubyte[] buf)
//		{
//			scope(exit) readerFiber = null;
//			NetRs rs;
//			if(eof)
//			{
//				disableRead();
//				rs.eof = true;
//				return rs;
//			}
//			
//			debug writeFlush("befor read ,fiber ",ExceptionSafeFiber.getThis().name,",sock ",sock," - ",cast(void*)this);
//			
//			readerFiber = ExceptionSafeFiber.getThis();
//			enforce(readerFiber !is null,new StdioException("Conn.readSome must be called in Fiber."));
//			
//			enableRead();
//			ExceptionSafeFiber.yield();
//			
//			if(err)
//			{
//				disableRead();
//				throw new StdioException("Unkown io error.");
//			}
//			
//			long toRead = readAvailBytes<buf.length?readAvailBytes:buf.length;
//			long bytes = recv(sock, buf.ptr, toRead, 0);
//			disableRead();
//			enforce (bytes != -1,new StdioException("Read from sock failed."));
//			
//			rs.eof = eof;
//			rs.bytes = cast(int)bytes;
//			
//			debug writeFlush("after read ,fiber ",ExceptionSafeFiber.getThis().name,",sock ",sock," - ",cast(void*)this);
//			
//			return rs;
//		}
//
//		public void write(ubyte[] buf)
//		{
//		}
//
//		public void writeTo(string ip,ushort port,ubyte[] buf)
//		{
//		}
//
//		public void connect(string ip,ushort port)
//		{
//		}
//	}

	class MacConnGlobals
	{
		static const int MAX_EVENT_COUNT = 100;
		static __gshared kevent_s[MAX_EVENT_COUNT] events;
	}

	ProviderAcceptor createAcceptor(string ip,ushort port, int backlog)
	{
		return new Acc(ip,port,backlog);
	}

	void selectAndProcessNetEvents(ulong maxWaitTimeInMs)
	{
		timespec spec = {0,maxWaitTimeInMs*1000000};
		kevent_s[] evts = MacConnGlobals.events[0..$];
		int ret = kevent(Fd.kq, null, 0, &evts[0], cast(int)evts.length, &spec);
		if (ret == -1)
		{
			writeFlush("kevent failed!");
			return;
		}
		
		handleEvent(Fd.kq, &evts[0], ret);
	}

	Conn connectTcp(string ip,ushort port)
	{
		int sock = createTcpSocket();
		scope(failure) close(sock);

		ClientMacConn conn = new ClientMacConn(sock);
		conn.connect(ip,port);
		return conn;
	}


}





