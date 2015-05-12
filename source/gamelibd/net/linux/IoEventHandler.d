module gamelibd.net.linux.IoEventHandler;

version (linux)
{
	/**
	 *  super class of Acceptor ,ServerConnection, ClientConnection
	 */
	import gamelibd.net.linux.epollapi;
	import gamelibd.exceptions;
	alias epoll_event TEvent;

	class IoEventHandler
	{
		import core.thread;
		import gamelibd.net.exceptionsafefiber;
		import gamelibd.mem;
		import gamelibd.util;


		
		int sock;
		int epfd;
		int interest;
		bool eof;
		bool err;
		Ptr!ExceptionSafeFiber readerFiber;
		Ptr!ExceptionSafeFiber writerFiber;
		
		void registerDisableWrite()
		{
			registerInterest(EPOLLIN);
		}
		
		void registerDisableRead()
		{
			registerInterest(EPOLLOUT);
		}
		
		void registerDisable()
		{
			registerInterest(0);
		}

		private void registerInterest(int events)
		{
			registerEv(epfd,sock,cast(void*)this,events);
			this.interest = events;
		}

		private void enableInterest(int singleInterest)
		{
			if(bitExist(interest,singleInterest))
			{
				return;
			}
			if(sock<0)
			{
				return;
			}
			singleInterest = this.interest | singleInterest;
			changeEv(epfd,sock,cast(void*)this,singleInterest);
			this.interest = singleInterest;
		}

		private void disableInterest(int singleInterest)
		{
			if(!bitExist(interest,singleInterest))
			{
				return;
			}
			if(sock<0)
			{
				return;
			}
			singleInterest = this.interest & (~singleInterest);
			changeEv(epfd,sock,cast(void*)this,singleInterest);
			this.interest = singleInterest;
		}

		void disableAll()
		{
			if(!bitExist(interest,EPOLLIN) && !bitExist(interest,EPOLLOUT))
			{
				return;
			}
			int singleInterest = 0;
			changeEv(epfd,sock,cast(void*)this,singleInterest);
			this.interest = singleInterest;
		}
		
		void enableRead()
		{
			enableInterest(EPOLLIN);
		}
		
		void disableRead()
		{
			disableInterest(EPOLLIN);
		}
		
		void enableWrite()
		{
			enableInterest(EPOLLOUT);
		}
		
		void disableWrite()
		{
			disableInterest(EPOLLOUT);
		}
		
		public void doRead(TEvent* evt)
		{
			writeFlush("calling blank doRead");
		}
		
		public void doWrite(TEvent* evt)
		{
			writeFlush("calling blank doWrite");
		}
		
		public void doErr()
		{
			this.err = true;
			tryResumeReaderFiber();
			tryResumeWriterFiber();
		}
		
		public void doEof()
		{
			this.eof = true;
		}

		/*
		 * sleep first , do dg when being waken
		 */
		protected void autoReaderFiberSetting(void delegate() dg)
		{
			readerFiber = ExceptionSafeFiber.getThis();
			enforce(readerFiber !is null,new IoException("Conn.xx must be called in Fiber."));
			scope(exit) readerFiber = null;
			
			ExceptionSafeFiber.yield();

			dg();
		}

		protected void autoWriterFiberSetting(void delegate() dg)
		{
			writerFiber = ExceptionSafeFiber.getThis();
			enforce(writerFiber !is null,new IoException("Conn.xx must be called in Fiber."));
			scope(exit) writerFiber = null;
			
			ExceptionSafeFiber.yield();
			
			dg();
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
				return;
			}
			
			readerFiber.resume();
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
				return;
			}

			writerFiber.resume();
		}
	}

}