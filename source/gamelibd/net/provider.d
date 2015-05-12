module gamelibd.net.provider;

import core.sys.posix.sys.socket;
public import core.sys.posix.netinet.in_;
union addrtransform
{
	sockaddr addr;
	sockaddr_in addrin;
}

interface Conn
{
	public string getRemoteIp();
	public ubyte[] getRemoteIpBytes();
	public ushort getRemotePort();
	public string getLocalIp();
	public ubyte[] getLocalIpBytes();
	public ushort getLocalPort();

	public int readSome(ubyte[] buf);
	public int writeSome(ubyte[] buf);
	public int read(ubyte[] buf);
	public int write(ubyte[] buf);
	public int readUtil(ubyte[] buf,string endflag);

	public bool isEof();
	
	public void close();
	
	public int getHandle();
}

interface UdpConn
{
	public int read(ref addrtransform addr,ubyte[] buf);
	public int writeTo(ref addrtransform addr,ubyte[] buf);
	
	public void close();
	
	public int getHandle();
}

interface ProviderAcceptor
{
	public Conn accept();
	
	public string getIp();
	public ushort getPort();

	public void close();
}

//ProviderConn function (string ip,ushort port, int backlog) createAcceptor;

//void function() selectAndProcessNetEvents;


