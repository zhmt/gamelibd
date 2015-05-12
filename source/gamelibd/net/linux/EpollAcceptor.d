module gamelibd.net.linux.EpollAcceptor;


import std.stdio;
import std.string;
import std.traits;
import std.exception : enforce;


version(linux)
{
	import gamelibd.util;
	import gamelibd.net.PosixApi;
	import core.thread;
	import gamelibd.net.provider;

	import gamelibd.net.linux.IoEventHandler;
	import gamelibd.net.linux.epollapi;
	import gamelibd.net.linux.TcpServerConn;

	class EpollAcceptor : IoEventHandler,ProviderAcceptor
	{
		protected int newsock;
		protected addrtransform newaddr;

		public this(string ip,ushort port,int backlog)
		{
			epfd = ConnGlobals.epfd;
			sock = createTcpListener(ip,port,backlog);
			//debug writeFlush(sock);
			registerDisableWrite();
		}

		public ~this()
		{
			close();
			debug writeFlush("close acceptor");
		}

		override public void doRead(TEvent* evt) {
			//debug writeFlush("acc doRead");
			doAccept(evt);
		}

		override public void close()
		{
			closeFd(sock);
		}
		
		public Conn accept()
		{
			TcpServerConn ret;
			autoReaderFiberSetting((){
					//debug writeFlush("newsock :",newsock);
					scope(failure) closeFd(newsock);
					ret = new TcpServerConn(newsock,newaddr);
				});
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

		private void doAccept( TEvent* evt)
		{
			import core.sys.posix.sys.socket;
			uint len = addrtransform.sizeof;
			newsock = accept(this.sock, cast(sockaddr*)&newaddr, &len);
			scope(failure) closeFd(newsock);
			tryResumeReaderFiber();
		}

	}
}



