module gamelibd.net.linux.linuxconn;


import gamelibd.mem;
import gamelibd.util;
import gamelibd.net.provider;
import gamelibd.net.exceptionsafefiber;

import std.stdio;
import std.string;
import std.traits;
import std.exception : enforce;

import gamelibd.net.PosixApi;
import gamelibd.net.linux.epollapi;
import gamelibd.net.linux.IoEventHandler;
import gamelibd.net.linux.EpollAcceptor;
import gamelibd.net.linux.TcpClientConn;
import gamelibd.net.linux.UdpLinuxConn;
import gamelibd.net.provider;



version(linux)
{
	void handleEvent(epoll_event[] evts)
	{
		foreach(epoll_event one;evts)
		{
			//debug writeFlush("handle event, udata:" , one.data.ptr);
			IoEventHandler handler = cast(IoEventHandler ) one.data.ptr;
			if(bitExist(one.events ,EPOLLERR))
			{
				debug writeFlush("doErr");
				handler.doErr();
				continue;
			}
			if( bitExist(one.events,EPOLLRDHUP) || bitExist(one.events,EPOLLHUP))
			{
				debug writeFlush("doEof");
				handler.doEof();
				continue;
			}
			if(bitExist(one.events , EPOLLIN))
			{
				//debug writeFlush("doRead");
				handler.doRead(&one);
				continue;
			}
			if(bitExist(one.events ,EPOLLOUT))
			{
				//debug writeFlush("doWrite");
				handler.doWrite(&one);
				continue;
			}
			debug writeFlush("doNothing",handler);
		}
	}
	
	void selectAndProcessNetEvents(ulong maxWaitTimeInMs)
	{
		epoll_event[] evts = ConnGlobals.events[0..$];
		//long now = utcNow();
		int n = epoll_wait(ConnGlobals.epfd,&evts[0],ConnGlobals.MAX_EVENT_COUNT,cast(int)maxWaitTimeInMs);
		//writeFlush(n);
		if (n == -1)
		{
			writeFlush("kevent failed!");
			return;
		}
		
		handleEvent(evts[0..n]);
	}


	ProviderAcceptor createAcceptor(string ip,ushort port,int backlog)
	{
		return new EpollAcceptor(ip,port,backlog);
	}

	Conn connectTcpImpl(string ip,ushort port)
	{
		TcpClientConn client = new TcpClientConn(ip,port);
		client.connect();
		return client;
	}

	UdpConn createUdpImpl()
	{
		int  sock = createUdpSocket();
		UdpConn ret = new UdpLinuxConn(sock);
		return ret;
	}

	UdpConn createUdpServerImpl(string ip,ushort port)
	{
		int sock = createUdpListener(ip,port);
		UdpConn ret = new UdpLinuxConn(sock);
		return ret;
	}
}