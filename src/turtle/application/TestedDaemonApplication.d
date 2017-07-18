/*******************************************************************************

    Provides ready-to-use abstraction for running tested application as a
    persistent background process that must not terminate on its own.

    Copyright: Copyright (c) 2016-2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.application.TestedDaemonApplication;

import core.stdc.stdlib;

import ocean.transition;
import ocean.task.util.Timer;

import turtle.runner.Logging;
import turtle.application.model.TestedApplicationBase;
import turtle.application.model.ExternalProcess;

/*******************************************************************************

    Extends TestedApplicationBase functionality with concept of "expecting
    termination" - the whole test suite will abort if tested application
    terminates when this object is not in matching state.

*******************************************************************************/

class TestedDaemonApplication : TestedApplicationBase
{
    /***************************************************************************

        As the process is expected to be daemon-like, it will abort the
        application if early unexpected termination is detected.

    ***************************************************************************/

    private final class ExternalDaemonProcess : ExternalProcess
    {
        private this ( cstring cmd, cstring work_dir,
            Const!(cstring)[] arguments = null, istring[istring] env = null )
        {
            super(cmd, work_dir, arguments, env);
        }

        override protected void finished ( bool exited_ok, int exit_code )
        {
            if ( !this.outer.expecting_termination )
            {
                .log.error("Early termination from '{}', aborting",
                    this.process.programName());
                abort();
            }
        }
    }

    /***************************************************************************

        Indicates if explicit application shut down sequence has been started.

    ***************************************************************************/

    private bool expecting_termination = false;

    /***************************************************************************

        Time to pause test suite task for after starting this application
        (in microseconds).

    ***************************************************************************/

    private uint delay;

    /***************************************************************************

        Constructor

        Params:
            executable_name = the name of the executable to test
            delay = time (in seconds) to pause test suite task after starting
                the tested application (to give time handshakes to succeed)
            sandbox = sandbox directory the tested application should use as
                working directory
            args = initial set of program arguments that will be supplied
                for all `start` calls
            env = environment variables to set for started process

    ***************************************************************************/

    public this ( cstring executable_name, double delay,
        cstring sandbox, Const!(cstring)[] args = null, istring[istring] env = null )
    {
        super(executable_name, sandbox);
        this.process = new ExternalDaemonProcess(this.executable_path, sandbox,
            args, env);
        this.delay = cast(uint) (delay * 1_000_000);
    }

    /***************************************************************************

        Starts external process in background mode. If it stops on its own
        before being explicitly requested to get killed

        Params:
            args = CLI arguments for the process

    ***************************************************************************/

    override public void start ( Const!(cstring)[] args = null )
    {
        this.expecting_termination = false;
        super.start(args);
        if (this.delay > 0)
            .wait(this.delay);
    }

    /***************************************************************************

        Stops application if it is running

    ***************************************************************************/

    override public void stop ( )
    {
        this.expecting_termination = true;
        super.stop();
    }
}
