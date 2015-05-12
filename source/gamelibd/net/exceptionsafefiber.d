module gamelibd.net.exceptionsafefiber;




import gamelibd.util;
import gamelibd.net.conn;
import core.thread:Fiber;

class ExceptionSafeFiber  : Fiber
{
	import core.thread;

private :
	void function()  fn;
	void delegate()  dg;
	string _name = "";
	LinkedList!ExceptionSafeFiber terminationWaiters;
	bool terminated = false;


	public @property string name()
	{
		return _name;
	}
	
	public this()
	{
		super(&runWrapper);
		terminationWaiters = new LinkedList!ExceptionSafeFiber;
	}
	
	public this(string name)
	{
		super(&runWrapper);
		terminationWaiters = new LinkedList!ExceptionSafeFiber;
		_name = name;
	}
	
	public this(void delegate() dg)
	{
		super(&runWrapper);
		terminationWaiters = new LinkedList!ExceptionSafeFiber;
		this.dg = dg;
	}
	
	public this(string name,void delegate() dg)
	{
		super(&runWrapper);
		terminationWaiters = new LinkedList!ExceptionSafeFiber;
		this.dg = dg;
		_name = name;
	}
	
	public this( void function() fn)
	{
		super(&runWrapper);
		terminationWaiters = new LinkedList!ExceptionSafeFiber;
		this.fn = fn;
	}
	
	public this(string name, void function() fn)
	{
		super(&runWrapper);
		terminationWaiters = new LinkedList!ExceptionSafeFiber;
		this.fn = fn;
		_name = name;
	}
	
	public  void resume()
	{
		if(super.state != Fiber.State.HOLD)
		{
			writeFlush("reusme fiber failed : terminated.");
			return ;
		}
		super.call();
	}
	
	protected void runWrapper()
	{
		try{
			if(dg !is null)
			{
				dg();
			}else if(fn !is null)
			{
				fn();
			}else{
				run();
			}
		}catch(Throwable e)
		{
			writeFlush("Fiber exit with exception: ",e.msg,"\r\n",e.info);
		}finally
		{
			terminated = true;
			notifyTerminationWaiters();
		}
	}
	
	public void run()
	{
	}
	
	public static ExceptionSafeFiber getThis()
	{
		return cast(ExceptionSafeFiber)Fiber.getThis();
	}

	public static void sleep(long timeInMs)
	{
		class Waiter : TimerTask
		{
			Ptr!ExceptionSafeFiber fiber;

			this(long startTime,ExceptionSafeFiber fiber)
			{
				super(startTime);
				this.fiber = fiber;
			}

			public override void run()
			{
				fiber.resume();
			}
		}

		ExceptionSafeFiber fiber = ExceptionSafeFiber.getThis();
		addTimeTask(new Waiter(utcNow()+timeInMs,fiber));
		ExceptionSafeFiber.yield();
	}

	public void join()
	{
		if(this.terminated || this.state==State.TERM)
		{
			return;
		}
		terminationWaiters.addTail(ExceptionSafeFiber.getThis());
		yield();
	}

	private void notifyTerminationWaiters()
	{
		while(!this.terminationWaiters.isEmpty)
		{
			terminationWaiters.removeHead().resume();
		}
	}
}


class TimerTask : ExceptionSafeFiber
{
	alias void delegate(TimerTask) FUNC;
	public long startTime;

	public this(long startTime)
	{
		super("timer");
		this.startTime = startTime;
	}

	public override void run()
	{
	}
}
