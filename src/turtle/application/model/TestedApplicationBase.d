/*******************************************************************************

    Copyright: Copyright (c) 2016-2017 dunnhumby Germany GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.application.model.TestedApplicationBase;

import core.stdc.stdlib;
import core.sys.posix.signal;
import core.sys.posix.sys.stat;

import ocean.core.Enforce;
import ocean.transition;
import ocean.core.Array;
import ocean.text.Util : join;
import ocean.text.util.StringC;
import ocean.task.Scheduler;
import ocean.io.select.client.TimerEvent;
import Path = ocean.io.Path;

import turtle.Exception;
import turtle.runner.Logging;
import turtle.application.model.ExternalProcess;

/*******************************************************************************

    Base class for all tested application wrappers. Currently CLI and Daemon
    mode tested application only differ in how they handle startup and
    termination of the process and major chunk of functionality can be shared.

*******************************************************************************/

abstract class TestedApplicationBase
{
    /***************************************************************************

        Timer instance used for iteratively trying to kill application
        with different signals. Can't be FiberTimerEvent because needs to be
        callable from epoll callback.

    ***************************************************************************/

    protected KillTimerEvent kill_timer;

    /***************************************************************************

        Fully qualified path to the executable

    ***************************************************************************/

    protected cstring executable_path;

    /***************************************************************************

        Short name of the executable

    ***************************************************************************/

    protected cstring executable_name;

    /***************************************************************************

        External process used to start and stop the application to test. Must
        be constructed by the derived class after TestedApplicationBase
        constructor has finished.

    ***************************************************************************/

    protected ExternalProcess process;

    /***************************************************************************

        Configures wait time after sending one of kill signals to external
        process before trying a "harder" signal.

    ***************************************************************************/

    public double stop_wait_delay = 0.1;

    /***************************************************************************

        Constructor

        Params:
            executable_name = the name of the executable to test
            sandbox = sandbox directory the tested application should use as
                working directory
            args = initial set of program arguments that will be supplied
                for all `start` calls
            env = environment variables to set for started process

    ***************************************************************************/

    public this ( cstring executable_name, cstring sandbox )
    {
        this.kill_timer = new KillTimerEvent(this);
        this.executable_name = executable_name;
        this.executable_path = Path.join(sandbox, executable_name);

        this.checkPaths();
    }

    /***************************************************************************

        Returns:
            'true' if underlying external process is currently running

    ***************************************************************************/

    public bool isRunning ( )
    {
        return this.process.isRunning() && this.pid() != -1;
    }

    /***************************************************************************

        Starts external process

        The method provides default implementation but is abstract to ensure
        derivatives make conscious decision about start/stop semantics.

        Params:
            args = CLI arguments for the process

    ***************************************************************************/

    public abstract void start ( Const!(cstring)[] args = null )
    {
        // disable previous kill timer if present
        this.kill_timer.reset();
        this.process.start(args);
        log.trace("pid {} : '{} {}'",
            this.process.pid(), this.executable_name, join(args, " "));
    }

    /***************************************************************************

        Stops application if it is running.

        Uses SIGTERM -> SIGKILL -> SIGABRT sequence with small wait time
        between them.

        The method provides default implementation but is abstract to ensure
        derivatives make conscious decision about start/stop semantics.

    ***************************************************************************/

    public abstract void stop ( )
    {
        auto sec = cast(uint) this.stop_wait_delay;
        auto millisec = cast(uint) ((this.stop_wait_delay - sec)
            * 1_000);
        // fire first event as soon as possible and others with
        // defined interval if needed
        this.kill_timer.set(0, 1, sec, millisec);
        theScheduler.epoll.register(this.kill_timer);
    }

    /***************************************************************************

        Return the running process' ID.

        Returns:
            Process ID if the process is running, -1 if not.

    ***************************************************************************/

    public pid_t pid ( )
    {
        return this.process.pid();
    }

    /***************************************************************************

        Makes sanity checks about well-formed state of configured paths.

    ***************************************************************************/

    private void checkPaths ( )
    {
        enforce!(TurtleException)(
            Path.exists(this.executable_path),
            cast(istring)("Test application " ~ this.executable_path ~
                " does not exist!")
        );

        enforce!(TurtleException)(
            Path.isFile(this.executable_path),
            cast(istring)(this.executable_path ~ " is not a file.")
        );

        stat_t stats;
        auto executable_path_c = this.executable_path.dup;

        enforce!(TurtleException)(
            stat(StringC.toCString(executable_path_c), &stats) == 0,
            cast(istring)("Could not access file attributes for '" ~
                this.executable_path ~ "'")
        );

        enforce!(TurtleException)(
            (stats.st_mode & S_IXUSR) != 0,
            cast(istring)(this.executable_path ~ " is not an executable")
        );
    }
}

/*******************************************************************************

    Binds together timer initiating kill signals and index variable indicating
    which signal to send on each event trigger. Ensures index is reset each time
    timer is reset.

*******************************************************************************/

private final class KillTimerEvent : TimerEvent
{
    /// Reference to bound application
    private TestedApplicationBase app;
    /// Indicates which signal number to use next
    private int signal_id = 0;

    /***************************************************************************

        Constructor

    ***************************************************************************/

    public this ( TestedApplicationBase app )
    {
        this.app = app;
        super(&this.nextSignal);
    }

    /***************************************************************************

        Resets both timer event and signal number

    ***************************************************************************/

    override public typeof(TimerEvent.reset()) reset ( )
    {
        this.signal_id = 0;
        return super.reset();
    }

    /***************************************************************************

        Called by timer event when app shutdown process has been started,
        attempts new kind of signal each time event repeats.

        Returns:
            'true' if timer event needs to stay registered,
            'false' otherwise

    ***************************************************************************/

    private bool nextSignal ( )
    {
        static signal_order = [ SIGTERM, SIGKILL, SIGABRT ];
        static signal_names = [ "SIGTERM", "SIGKILL", "SIGABRT" ];

        if (!this.app.isRunning())
            return false;

        auto i = this.signal_id;

        if (i >= signal_order.length)
        {
            .log.error(
                "Tested application kept running even after SIGABRT");
            assert(false);
        }

        log.trace("Sending {} to the tested application (pid {})",
            signal_names[i], this.app.pid());
        this.app.process.kill(signal_order[i]);
        this.signal_id++;

        return true;
    }
}
