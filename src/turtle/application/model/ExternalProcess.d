/*******************************************************************************

    Base type that wraps externally executed process and provides idiomatic
    means to start/stop it.

    Copyright: Copyright (c) 2016-2017 dunnhumby Germany GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.application.model.ExternalProcess;

import core.stdc.stdlib;
import core.sys.posix.signal;

import ocean.transition;
import ocean.util.log.Logger;
import ocean.text.Util;
import ocean.sys.ErrnoException;
import ocean.io.select.client.EpollProcess;
import ocean.task.Scheduler;

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

    private const(cstring)[] arguments;

    /***************************************************************************

        Stores last output lines from the external process

    ***************************************************************************/

    protected cstring[100] last_output;

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
        const(cstring)[] arguments = null, string[string] env = null )
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
            {
                this.rotateOutputLines(line);
                this.process_log.trace(line);
            }
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
            {
                this.rotateOutputLines(line);
                this.process_log.error(line);
            }
        }
    }

    /***********************************************************************

        Start binary in sandbox and leave it running until `stop`
        is called

        Params:
            extra_args = additional arguments to append to ones defined in
                constructor when starting the process

    ***********************************************************************/

    public override void start ( const(cstring)[] extra_args = null )
    {
        this.startImpl(extra_args);
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

    protected void startImpl ( const(cstring)[] extra_args )
    {
        this.process.setWorkDir(this.work_dir.dup);
        super.start(command ~ this.arguments ~ extra_args);
    }

    /***************************************************************************

        Appends to the front of `this.last_output` buffer, shifting existing
        elements towards its end (but never resizing).

    ***************************************************************************/

    private void rotateOutputLines ( cstring line )
    {
        for (ptrdiff_t i = this.last_output.length-1; i > 0; --i)
            this.last_output[i-1] = this.last_output[i];
        this.last_output[$-1] = line;
    }
}
