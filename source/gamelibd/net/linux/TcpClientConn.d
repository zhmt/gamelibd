module gamelibd.net.linux.TcpClientConn;

version(linux)
{
	import gamelibd.net.linux.TcpLinuxConn;
	import gamelibd.net.PosixApi;
	import gamelibd.exceptions;
	import gamelibd.net.provider;
	import gamelibd.util;
	
	class TcpClientConn  : TcpLinuxConn
	{
		private string ip;
		private ushort port;
		private bool connected = false;

		this(string ip,ushort port)
		{
			int sock = createTcpSocket();
			scope (failure) closeFd(sock);
			addrtransform localAddr;
			super(sock,localAddr,localAddr);
			this.ip = ip;
			this.port = port;
			addrtransform addr = parseIpPort(ip,port);
			remoteAddr = addr;
		}

		public void connect()
		{	
			import core.sys.posix.sys.socket;
			import core.stdc.errno;
			import std.string;

			scope (failure) closeFd(sock);

			int rs = connect(sock, cast(sockaddr*) &remoteAddr, addrtransform.sizeof);
			if(rs<0 && errno != EINPROGRESS )
			{
				throw new IoException(format("Connect failed : %s:%s",ip,port));
			}
			
			if(rs==0)
			{
				connected = true;
				getSockLocalAddr(sock,localAddr);
				registerDisable();
			}else
			{
				registerDisableRead();
				scope (exit) disableRead();
				autoWriterFiberSetting((){
						if(!err)
						{
							connected = true;
							disableAll();
						}else
						{
							throw new IoException(format("Connect failed : %s:%s",ip,port));
						}
					});
			}
			//debug writeFlush("connected ",connected);
		}
		
		~this()
		{
			close();
			debug writeFlush("TcpClientConn deleted");
		}

	}
	
	
}