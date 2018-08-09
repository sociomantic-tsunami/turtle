/*******************************************************************************

    Provides ready-to-use abstraction for running tested application as a
    persistent background process that must not terminate on its own.

    Copyright: Copyright (c) 2016-2017 dunnhumby Germany GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.application.TestedDaemonApplication;

import core.stdc.stdlib;

import ocean.transition;
import ocean.task.util.Timer;
import ocean.task.Scheduler;
import ocean.io.select.client.TimerEvent;
import ocean.text.convert.Formatter;
import ocean.text.Util;
import ocean.util.log.Logger;

import turtle.runner.Logging;
import turtle.application.model.TestedApplicationBase;
import turtle.application.model.ExternalProcess;
import turtle.application.Stats;

/*******************************************************************************

    Extends TestedApplicationBase functionality with concept of "expecting
    termination" - the whole test suite will abort if tested application
    terminates when this object is not in matching state.

*******************************************************************************/

class TestedDaemonApplication : TestedApplicationBase
{
    /***************************************************************************

        Timer instance used to check resource consumption by tested app and
        record peak stats.

    ***************************************************************************/

    protected StatsGrabber stats_grabber;

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
                .log.error(
                    "Early termination from '{}', aborting.",
                    join(this.process.args, " ")
                );

                .log.error("Last console output:");

                foreach (line; this.last_output[])
                {
                    if (line.length)
                        .log.error(line);
                }

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
        this.stats_grabber = new StatsGrabber(this);
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
        // collect stats each 10 milliseconds
        this.stats_grabber.set(0, 1, 0, 10);
        theScheduler.epoll.register(this.stats_grabber);
    }

    /***************************************************************************

        Stops application if it is running

    ***************************************************************************/

    override public void stop ( )
    {
        this.stats_grabber.reset();
        this.expecting_termination = true;
        super.stop();
    }

    /***************************************************************************

        Returns:
            stats for peak resource usage by the application

    ***************************************************************************/

    public PeakStats getPeakStats ( )
    {
        return this.stats_grabber.peak_stats;
    }
}

/*******************************************************************************

    Fires regular triggers to collect tested application memory consumption
    stats.

*******************************************************************************/

private final class StatsGrabber : TimerEvent
{
    import ocean.sys.stats.linux.ProcVFS;

    /// Reference to bound application
    private TestedApplicationBase app;
    /// Updated by timer
    private PeakStats peak_stats;

    /***************************************************************************

        Constructor

    ***************************************************************************/

    public this ( TestedApplicationBase app )
    {
        this.app = app;
        super(&this.checkStats);
    }

    /***************************************************************************

        Resets both timer event and stored stats

    ***************************************************************************/

    override public typeof(TimerEvent.reset()) reset ( )
    {
        this.peak_stats = PeakStats.init;
        return super.reset();
    }

    /***************************************************************************

        Called by timer event with a very small interval

    ***************************************************************************/

    private bool checkStats ( )
    {
        try
        {
            auto stats = getProcStat(format("/proc/{}/stat", this.app.pid()));
            if (this.peak_stats.vsize < stats.vsize)
                this.peak_stats.vsize = stats.vsize;
            return true;
        }
        catch (Exception e)
        {
            .log.error("{} ({}:{})", e.message(), e.file, e.line);
            return false;
        }
    }
}
