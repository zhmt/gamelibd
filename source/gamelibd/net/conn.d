module gamelibd.net.conn;

import std.exception:enforce;
import std.stdio;

import gamelibd.util;
public import gamelibd.net.provider;

import gamelibd.net.macconn;
import gamelibd.net.linux.linuxconn;

public import gamelibd.mem;
public import gamelibd.net.EventLoop;
public import gamelibd.net.provider : Conn;
public import gamelibd.net.exceptionsafefiber;

class Acceptor
{
private:
	string ip;
	ushort port;
	int backlog;
	ProviderAcceptor acc;
	
public:

	~this()
	{
		acc.close();
	}
	
	public void listen(string ip,ushort port,int backlog)
	{
		this.ip = ip;
		this.port = port;
		this.backlog = backlog;
		acc = createAcceptor(ip,port,backlog);
	}
	
	public void accept(void delegate(Ptr!Conn c) connHandler)
	{
		internalAccept(connHandler);
	}

	private void internalAccept(T)(T connHandler)
	{
		spawn({
				writeFlush("listen");
				while(true)
				{
					Conn tmp = acc.accept();
					Ptr!Conn c = tmp;
					spawn({
							connHandler(c);
						});
				}
			});
	}
}

Ptr!Conn connect(string ip,ushort port)
{
	Conn tmp = connectTcpImpl(ip,port);
	Ptr!Conn conn = tmp;
	return conn;
}

Ptr!UdpConn  createUdp()
{
	UdpConn tmp = createUdpImpl();
	Ptr!UdpConn ret = tmp;
	return ret;
}

Ptr!UdpConn  createUdpServer(string ip,ushort port)
{
	UdpConn tmp = createUdpServerImpl(ip,port);
	Ptr!UdpConn ret = tmp;
	return ret;
}

 ExceptionSafeFiber spawn(void delegate() dg)
{
	return EventLoop.loop.spawn(dg);
}

 ExceptionSafeFiber spawn(string name,void delegate() dg)
{
	return EventLoop.loop.spawn(name,dg);
}

 ExceptionSafeFiber spawn(ExceptionSafeFiber fiber)
{
	return EventLoop.loop.spawn(fiber);
}

void addTimeTask(TimerTask task)
{
	EventLoop.loop.addTimeTask(task);
}

void startEventLoop()
{
	EventLoop.loop.startEventLoop();
}

