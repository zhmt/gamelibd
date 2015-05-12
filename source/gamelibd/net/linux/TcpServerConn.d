module gamelibd.net.linux.TcpServerConn;

version(linux)
{

	import gamelibd.net.linux.TcpLinuxConn;
	import gamelibd.net.PosixApi;
	import gamelibd.net.provider;
	import gamelibd.util;

	class TcpServerConn  : TcpLinuxConn
	{
		this(int sock,addrtransform remoteAddr)
		{
			scope (failure) closeFd(sock);
			setNonBlock(sock);
			addrtransform localAddr;
			getSockLocalAddr(sock,localAddr);
			super(sock,localAddr,remoteAddr);
			registerDisable();
		}

		~this()
		{
			close();
			debug writeFlush("TcpServerConn deleted");
		}
	}


}