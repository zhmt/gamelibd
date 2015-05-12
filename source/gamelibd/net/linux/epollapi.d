module gamelibd.net.linux.epollapi;

import std.stdio;
import std.string;
import std.traits;
import std.exception : enforce;

//epoll api
version(linux) {
extern(C):
	alias int c_int;
	
	alias uint uint32_t;
	alias ulong uint64_t;

	align(1) struct epoll_event 
	{
	align(1):
		uint events;
		epoll_data data;
	};
	
	union epoll_data
	{
		void *ptr;
		int fd;
		uint u32;
		ulong u64;
	};
	
	/* Valid opcodes ( "op" parameter ) to issue to epoll_ctl().  */
	enum
	{
		EPOLL_CTL_ADD = 1, // Add a file descriptor to the interface.
		EPOLL_CTL_DEL = 2, // Remove a file descriptor from the interface.
		EPOLL_CTL_MOD = 3, // Change file descriptor epoll_event structure.
	}
	

	enum
	{
		EPOLL_CLOEXEC  = 0x80000,
		EPOLL_NONBLOCK = 0x800
	}


	enum 
	{
		EPOLLIN 	= 0x001,
		EPOLLPRI 	= 0x002,
		EPOLLOUT 	= 0x004,
		EPOLLRDNORM = 0x040,
		EPOLLRDBAND = 0x080,
		EPOLLWRNORM = 0x100,
		EPOLLWRBAND = 0x200,
		EPOLLMSG 	= 0x400,
		EPOLLERR 	= 0x008,
		EPOLLHUP 	= 0x010,
		EPOLLRDHUP 	= 0x2000, // since Linux 2.6.17
		EPOLLONESHOT = 1u << 30,
		EPOLLET 	= 1u << 31
	}
	
	int epoll_create1(int flags);
	int epoll_ctl(int epfd, int op, int fd, epoll_event* event);
	int epoll_wait(int epfd, epoll_event* events, int maxevents, int 
		timeout);
}

// epoll api wrapper
version(linux)
{
	class ConnGlobals
	{
		static const int MAX_EVENT_COUNT = 100;
		static __gshared epoll_event[MAX_EVENT_COUNT] events;
		public static __gshared const int epfd;
		
		static this() { epfd = epoll_create1(0); }
	}

	void registerEv(int epfd, int fd,void* userData,int events)
	{
		epoll_event evt;
		evt.data.ptr = userData;
		evt.events = events;
		
		int ret = epoll_ctl(epfd,EPOLL_CTL_ADD,fd,&evt);
		enforce (ret != -1,new StdioException("Register event failed."));
	}
	
	void changeEv(int epfd, int fd,void* userData,int events)
	{
		epoll_event evt;
		evt.data.ptr = userData;
		evt.events = events;
		
		int ret = epoll_ctl(epfd,EPOLL_CTL_MOD,fd,&evt);
		enforce (ret != -1,new StdioException("changeEv failed."));
	}
	
	void delEv(int epfd,int fd)
	{
		epoll_event evt;
		
		int ret = epoll_ctl(epfd,EPOLL_CTL_DEL,fd,&evt);
		enforce (ret != -1,new StdioException("delEv failed."));
	}
	
	bool bitExist(int data,int check)
	{
		return (data & check)!=0;
	}
}