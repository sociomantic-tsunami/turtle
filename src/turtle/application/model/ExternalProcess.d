/*******************************************************************************

    Base type that wraps externally executed process and provides idiomatic
    means to start/stop it.

    Copyright: Copyright (c) 2016-2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.application.model.ExternalProcess;

import core.stdc.stdlib;
import core.sys.posix.signal;

import ocean.transition;
import ocean.util.log.Log;
import ocean.text.Util;
import ocean.text.convert.Format;
import ocean.sys.ErrnoException;
import ocean.io.select.client.EpollProcess;
import ocean.task.Scheduler;
import ocean.core.Traits;

import turtle.runner.Logging;

/*******************************************************************************

    Shared code for all external processes

*******************************************************************************/

class ExternalProcess : EpollProcess
{
    /***************************************************************************

        Exception instance used to report `kill` call related issues.

    ***************************************************************************/

    private ErrnoException errno_e;

    /***************************************************************************

        Set by descendant, command to run process

    ***************************************************************************/

    protected cstring command;

    /***************************************************************************

        Set by descendant, working directory

    ***************************************************************************/

    protected cstring work_dir;

    /***************************************************************************

        Logger for outputting program stdout/stderr.

    ***************************************************************************/

    protected Logger process_log;

    /***************************************************************************

        Arguments to pass to the external process

    ***************************************************************************/

    private Const!(cstring)[] arguments;

    /***************************************************************************

        Constructor

        Params:
            cmd = command to run externally
            work_dir = working directory to set for external process
            arguments = common arguments to pass to the external process
            env  = associative array of strings containing the environment
                variables for the process. The variable name should be the key
                used for each entry.

    ***************************************************************************/

    public this ( cstring cmd, cstring work_dir,
        Const!(cstring)[] arguments = null, istring[istring] env = null )
    {
        this.errno_e = new ErrnoException;
        this.command = cmd;
        this.work_dir = work_dir;
        this.arguments = arguments;

        super(theScheduler.epoll());

        if ( env )
            this.process.setEnv(env);
        else
            this.process.copyEnv(true);

        static cstring basename ( cstring name )
        {
            for ( long i = name.length - 1; i >= 0; --i )
            {
                if (name[i] == '/')
                    return name[i + 1 .. $];
            }

            return name;
        }

        this.process_log = Log.lookup(basename(this.command));
    }

    /***************************************************************************

        Callback that handles stdout data

        Params:
            data = chunk of data from external process stdout pipe

    ***************************************************************************/

    override protected void stdout ( ubyte[] data )
    {
        foreach (line; splitLines(cast(mstring) data))
        {
            if (line.length)
                this.process_log.trace("{}", line);
        }
    }

    /***************************************************************************

        Callback that handles stderr data

        Params:
            data = chunk of data from external process stderr pipe

    ***************************************************************************/

    override protected void stderr ( ubyte[] data )
    {
        foreach (line; splitLines(cast(mstring) data))
        {
            if (line.length)
                this.process_log.error("{}", line);
        }
    }

    // For forwards compatibility with Ocean v1.31, where an overload of
    // EpollProcess.start with one argument has been added, we need to adapt
    // the API of this class in Turtle. This is to fix the following problem
    // when the user calls `start` with one argument:
    //
    // 1) D2 favours `EpollProcess.start` with exactly one argument as the
    //    best match. It requires the user to explicitly alias this method in the
    //    derived class.
    //
    // 2) D1 cannot automatically decide between the version
    //    with one argument, and the version with one argument + a default
    //    argument.
    static if (hasMethod!(EpollProcess, "start",
                void delegate (Const!(mstring)[])))
    {
        /***********************************************************************

            Start binary in sandbox and leave it running until `stop`
            is called

            Params:
                extra_args = additional arguments to append to ones defined in
                    constructor when starting the process

        ***********************************************************************/

        public override void start ( Const!(mstring)[] extra_args = null )
        {
            this.startImpl(extra_args);
        }
    }
    else
    {
        /***********************************************************************

            Start binary in sandbox and leave it running until `stop`
            is called

            Params:
                extra_args = additional arguments to append to ones defined in
                    constructor when starting the process
                monitor = unused, for API compatibility with EpollProcess

        ***********************************************************************/

        public override void start ( Const!(mstring)[] extra_args = null,
                ProcessMonitor monitor = null )
        {
            this.startImpl(extra_args);
        }
    }

    /***************************************************************************

        Send the signal to the process

        Params:
            signal = signal number to send (i.e. 9 for SIGKILL)

    ***************************************************************************/

    public void kill ( int signal )
    {
        static bool ok ( int status ) { return status == 0; }
        this.errno_e.enforceRet!(.kill)(&ok).call(this.process.pid(), signal);
    }

    /***************************************************************************

        Check process state by sending signal 0 to it

        Return:
            'true' if process is running

    ***************************************************************************/

    public bool isRunning ( )
    {
        return .kill(pid, 0) == 0;
    }

    /***************************************************************************

        Return the running process' ID.

        Returns:
            Process ID if the process is running, -1 if not.

    ***************************************************************************/

    public pid_t pid ( )
    {
        return this.process.pid;
    }

    /***************************************************************************

        Start the tested application and leave it running until `stop` is
        called.  Extracted here as the user will call it via appropriate
        interface, depending on the ocean version.

        Params:
            extra_args = additional arguments to append to ones defined in
                constructor when starting the process


    ***************************************************************************/

    protected void startImpl ( Const!(mstring)[] extra_args )
    {
        this.process.setWorkDir(this.work_dir.dup);

        // For forwards compatibility with Ocean 1.31 we cannot call
        // EpollProcess.start which accepts two arguments. This is to avoid the
        // deprecated method from recursively calling ExternalProcess.start.

        static if (hasMethod!(EpollProcess, "start",
                    void delegate (Const!(mstring)[])))
        {
            super.start(command ~ this.arguments ~ extra_args);
        }
        else
        {
            super.start(command ~ this.arguments ~ extra_args, null);
        }
    }

}
