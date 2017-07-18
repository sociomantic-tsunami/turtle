/*******************************************************************************

    Provides ready-to-use abstraction for running tested application as a
    "run-and-wait" command line tool.

    Copyright: Copyright (c) 2016-2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.application.TestedCliApplication;

import core.stdc.stdlib;
import core.sys.posix.signal;

import ocean.transition;
import ocean.io.select.client.TimerEvent;
import ocean.task.Scheduler;
import ocean.task.Task;

import turtle.runner.Logging;
import turtle.application.model.TestedApplicationBase;
import turtle.application.model.ExternalProcess;

/*******************************************************************************

    Extends TestedApplicationBase functionality to store piped stdout/stderr
    text between `start` calls. Modified `start` to block calling task until
    started process ends on its own or times out.

*******************************************************************************/

class TestedCliApplication : TestedApplicationBase
{
    /***************************************************************************

        Stores stdout/stderr and exit status code for spawned process

    ***************************************************************************/

    private final class ExternalCliProcess : ExternalProcess
    {
        private this ( cstring cmd,
            cstring work_dir, Const!(cstring)[] arguments = null,
            istring[istring] env = null )
        {
            super(cmd, work_dir, arguments, env);
        }

        override protected void stdout ( ubyte[] data )
        {
            this.outer.stdout_buffer ~= cast(mstring) data;
            super.stdout(data);
        }

        override protected void stderr ( ubyte[] data )
        {
            this.outer.stderr_buffer ~= cast(mstring) data;
            super.stderr(data);
        }

        override protected void finished ( bool exited_ok, int exit_code )
        {
            assert(this.outer.host_task !is null);
            this.outer.exit_code = exit_code;
            this.outer.host_task.resume();
        }
    }

    /***************************************************************************

        Reference to task instance used to start the application

    ***************************************************************************/

    private Task host_task;

    /***************************************************************************

        Text written to stdout by tested application process during last
        `start()` call.

    ***************************************************************************/

    private mstring stdout_buffer;

    /***************************************************************************

        Text written to stderr by tested application process during last
        `start()` call.

    ***************************************************************************/

    private mstring stderr_buffer;

    /***************************************************************************

        Amount of seconds to wait before killing tested application with
        a signal.

    ***************************************************************************/

    private double timeout;

    /***************************************************************************

        Timer event which initiates killing of tested application if
        timeout was reached.

    ***************************************************************************/

    private TimerEvent timeout_killer;

    /***************************************************************************

        Stores exit status code of tested application from last `start()`
        call.

    ***************************************************************************/

    private int exit_code;

    /***************************************************************************

        Constructor

        Params:
            executable_name = the name of the executable to test
            timeout = how long to wait for process to end on its own before
                killing it
            sandbox = sandbox directory the tested application should use as
                working directory
            args = initial set of program arguments that will be supplied
                for all `start` calls
            env = environment variables to set for started process

    ***************************************************************************/

    public this ( cstring executable_name, double timeout,
        cstring sandbox, Const!(cstring)[] args = null, istring[istring] env = null )
    {
        super(executable_name, sandbox);
        this.process = new ExternalCliProcess(this.executable_path, sandbox,
            args, env);
        this.timeout = timeout;
        this.timeout_killer = new TimerEvent(&this.onTimeout);
    }

    /***************************************************************************

        Returns:
            exit status code of tested application from last `start()` call.

    ***************************************************************************/

    public int lastStatusCode ( )
    {
        return this.exit_code;
    }

    /***************************************************************************

        Starts external process in background mode. If it stops on its own
        before being explicitly requested to get killed

        Params:
            args = CLI arguments for the process

    ***************************************************************************/

    override public void start ( Const!(cstring)[] args = null )
    {
        this.stdout_buffer.length = 0;
        this.stderr_buffer.length = 0;
        enableStomping(this.stdout_buffer);
        enableStomping(this.stderr_buffer);

        this.host_task = Task.getThis();

        timespec delay;
        delay.tv_sec = cast(ulong) this.timeout;
        delay.tv_nsec = cast(ulong) ((this.timeout - delay.tv_sec)
            * 1_000_000_000);
        this.timeout_killer.set(delay);
        theScheduler.epoll.register(this.timeout_killer);

        super.start(args);

        this.host_task.suspend();
    }

    /***************************************************************************

        Stops application if it is running

    ***************************************************************************/

    override public void stop ( )
    {
        super.stop();
    }

    /***************************************************************************

        Returns:
            All stdout from tested application since last `start()` call as
            single string.

    ***************************************************************************/

    public cstring last_stdout ( )
    {
        return this.stdout_buffer;
    }

    /***************************************************************************

        Returns:
            All stderr from tested application since last `start()` call as
            single string.

    ***************************************************************************/

    public cstring last_stderr ( )
    {
        return this.stderr_buffer;
    }

    /***************************************************************************

        Callback when the timeout timer has triggered.
        This will stop the application and deregister from the epoll.

        Return:
            False to de-register from the epoll.

    ***************************************************************************/

    private bool onTimeout ( )
    {
        this.stop();
        return false;
    }
}
