module gamelibd.net.PosixApi;

import std.exception : enforce;
import std.string;
import std.stdio;

version(Posix)
{

	public import core.sys.posix.sys.socket;
	public import core.stdc.config;
	public import core.sys.posix.sys.types; // for time_t, suseconds_t
	public import core.sys.posix.unistd;
	public import core.sys.posix.netinet.in_;
	public import core.stdc.string : memcpy;
	public import core.sys.posix.arpa.inet : htons;
	public import core.sys.posix.netdb : gethostbyname;


	import gamelibd.net.provider;

	void setNonBlock(int fd) 
	{
		import core.sys.posix.fcntl : fcntl, F_GETFL, F_SETFL, O_NONBLOCK;
		int flags = fcntl(fd, F_GETFL);
		flags |= O_NONBLOCK;
		int err = fcntl(fd, F_SETFL, flags);
		enforce(err!=-1,new StdioException("setNonBlock failed."));
	}

	void setSockOpt(int sock,int param,int opt)
	{
		//SOL_SOCKET
		int on = 1;
		int err = setsockopt(sock, param, opt, &on, on.sizeof);
		enforce(err!=-1,new StdioException("setSockOpt failed."));
	}

	void setTcpNodelay(int sock)
	{
		//setsockopt(m_sock,IPPROTO_TCP,TCP_NODELAY,(char *)&flag,sizeof(flag))
		import core.sys.posix.netinet.tcp;
		setSockOpt(sock,IPPROTO_TCP,TCP_NODELAY);
	}

	void setSoreuseaddress(int sock)
	{
		import core.sys.posix.netinet.tcp;
		setSockOpt(sock,SOL_SOCKET,SO_REUSEADDR);
	}

	int createUdpSocket()
	{
		int sock = socket(AF_INET,SOCK_DGRAM,0);
		scope(failure) close(sock);
		enforce(sock!=-1,new StdioException("createTcpSocket failed."));
		setNonBlock(sock);
		return sock;
	}

	addrtransform parseIpPort(string ip ,ushort port)
	{
		addrtransform tran;
		tran.addrin.sin_family = AF_INET;
		tran.addrin.sin_port = htons(port);
		auto h = gethostbyname(ip.toStringz());
		memcpy(&tran.addrin.sin_addr.s_addr, h.h_addr, h.h_length);
		return tran;
	}

	int createUdpListener(string ip,ushort port)
	{
		int sock = createUdpSocket();
		scope(failure) close(sock);
		
		addrtransform addr = parseIpPort(ip,port);
		
		enforce(bind(sock, cast(sockaddr*) &addr.addrin, addr.sizeof) != -1,
			new StdioException(format("Bind failed at %s : %s",ip,port)));
		
		return sock;
	}

	int createTcpSocket()
	{
		int sock = socket(AF_INET,SOCK_STREAM,0);
		enforce(sock!=-1,new StdioException("createTcpSocket failed."));
		setNonBlock(sock);
		setTcpNodelay(sock);
		return sock;
	}

	int createTcpListener(string ip,ushort port,int backlog)
	{
		int sock = createTcpSocket();
		scope(failure) close(sock);

		setSoreuseaddress(sock);
		addrtransform addr = parseIpPort(ip,port);
		
		enforce(bind(sock, cast(sockaddr*) &addr.addrin, addr.sizeof) != -1,
			new StdioException(format("Bind failed at %s : %s",ip,port)));
		
		enforce(listen(sock,backlog)!=-1,
			new StdioException(format("Listen failed at %s : %s",ip,port)));
		
		return sock;
	}
	
	string addrToIp(ref addrtransform addr)
	{
		ubyte[4] ip = addrToIpBytes(addr);
		return format("%d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3]);
	}

	ubyte[] addrToIpBytes(ref addrtransform addr)
	{
		//import std.bitmanip;
		//return std.bitmanip.nativeToBigEndian!(uint)(cast(uint)local.addrin.sin_addr.s_addr);
		//ubyte[4] ip = (cast(ubyte*)&addr.addrin.sin_addr.s_addr)[0 .. 4];
		return  (cast(ubyte*)&addr.addrin.sin_addr.s_addr)[0 .. 4];
	}

	void closeFd(ref int fd)
	{
		if(fd>0) 
		{
			core.sys.posix.unistd.close(fd);
			fd = -1;
		}
	}

	addrtransform getSockLocalAddr(int sock,ref addrtransform localAddr)
	{
		uint size = sockaddr.sizeof;
		int suc = getsockname(sock,&localAddr.addr,&size);
		enforce(suc != -1,new StdioException("get local addr failed."));
		return localAddr;
	}
}

