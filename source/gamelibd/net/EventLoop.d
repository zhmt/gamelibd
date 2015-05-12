module gamelibd.net.EventLoop;

import gamelibd.util;
import gamelibd.net.exceptionsafefiber;
import gamelibd.net.macconn;
import gamelibd.net.linux.linuxconn;


class A{}

class EventLoop
{
	import std.container;
	alias RedBlackTree!(TimerTask,"a.startTime < b.startTime",true)  RbTree;
private :
	LinkedList!(ExceptionSafeFiber) fiberTask;
	RbTree timerTasks;

	public __gshared EventLoop loop;
	
	static this()
	{
		loop = new EventLoop();
	}

public:
	this()
	{
		fiberTask = new LinkedList!ExceptionSafeFiber;
		timerTasks = new RbTree();
	}

	public void addTimeTask(TimerTask task)
	{
		timerTasks.insert(task);
	}
	
	public ExceptionSafeFiber spawn(void function() fn)
	{
		return spawnFunc(fn);
	}
	
	public ExceptionSafeFiber spawn(void delegate() dg)
	{
		return spawnFunc(dg);
	}
	
	public ExceptionSafeFiber spawn(string name,void function() fn)
	{
		return spawnFunc(name,fn);
	}
	
	public ExceptionSafeFiber spawn(string name,void delegate() dg)
	{
		return spawnFunc(name,dg);
	}
	
	public ExceptionSafeFiber spawn(ExceptionSafeFiber fiber)
	{
		fiberTask.addTail(fiber);
		return fiber;
	}
	
	private ExceptionSafeFiber spawnFunc(FUNC)(FUNC fn)
	{
		ExceptionSafeFiber fiber = new ExceptionSafeFiber(fn);
		return spawn(fiber);
	}
	
	private ExceptionSafeFiber spawnFunc(FUNC)(string name,FUNC fn)
	{
		ExceptionSafeFiber fiber = new ExceptionSafeFiber(name,fn);
		return spawn(fiber);
	}
	
	public void startEventLoop()
	{
		while (true)
		{
			//writeFlush("main loop start once");
			int taskCount = 0;
			while(!fiberTask.isEmpty())
			{
				taskCount++;
				ExceptionSafeFiber task = fiberTask.removeHead();
				task.call();
				if(taskCount>10000)
				{
					break;
				}
			}

			taskCount = 0;
			while(timerTasks.length>0)
			{
				taskCount++;
				TimerTask task = timerTasks.front();
				if(utcNow()>task.startTime)
				{
					timerTasks.removeFront();
					task.run();
				}else
				{
					break;
				}
				if(taskCount>10000)
				{
					break;
				}
			}

			selectAndProcessNetEvents(4);
		}
	}
}

