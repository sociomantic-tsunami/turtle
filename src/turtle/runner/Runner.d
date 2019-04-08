/*******************************************************************************

    Base task class for test runner and application class to handle
    command-line flags to forward to that test runner.

    Copyright: Copyright (c) 2015-2017 dunnhumby Germany GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.runner.Runner;

import Version;

static if (is(typeof(version_info)))
    alias version_info v_info;
else
    alias versionInfo v_info;

import core.thread;
import core.sys.posix.sys.stat;

import ocean.transition;
import ocean.core.Time;
import ocean.core.Array;
import ocean.core.Enforce;
import ocean.core.Array;
import ocean.stdc.posix.sys.un;
import ocean.io.FilePath;
import ocean.io.Stdout;
import ocean.sys.Environment;
import ocean.util.app.CliApp;
import ocean.task.Scheduler;
import ocean.task.Task;
import ocean.task.extensions.ExceptionForwarding;
import ocean.task.util.Timer;
import ocean.text.Arguments;
import ocean.util.log.Logger;
import ocean.text.convert.Formatter;
import ocean.text.util.StringC;
import ocean.stdc.posix.stdlib  : mkdtemp;

import turtle.TestCase;
import turtle.Exception;
import turtle.runner.Context;
import turtle.runner.Logging;
import turtle.runner.internal.RunnerConfig;
import turtle.application.TestedDaemonApplication;
import turtle.application.TestedCliApplication;
import turtle.env.Shell;
import turtle.env.model.Registry;
import turtle.env.ControlSocket;

// import aggregator
struct Actions
{
    import turtle.runner.actions.RunAll : runAll;
    import turtle.runner.actions.RunTwiceCompareStats : runTwiceCompareStats;
    import turtle.runner.actions.RunOne : runOne;
    import turtle.runner.actions.List : listAllTests;
}

/*******************************************************************************

    Used to differentiate between the three main turtle test modes:
    * A persistent tested application which is run as a background service
      (i.e. a daemon).
    * A tested application which runs and exits, presumably once per test case
      (i.e. a CLI application).
    * Connecting/attaching to already running application with no sandbox setup,
      means tested app is not controlled by turtle at all.

    There is also a special "manual" mode for use when the tested application
    is run manually but sandbox is still created. It is mostly a legacy option
    that existed before `TestedAppKind.None` but very few apps use it to
    implement custom daemon app starting logic in tests.

*******************************************************************************/

enum TestedAppKind
{
    Daemon,
    CLI,
    Manual,
    None
}

/*******************************************************************************

    Ocean scheduler task responsible for finding and executing all test
    cases. All required context is configured by application class that
    owns the task instance.

*******************************************************************************/

class TurtleRunnerTask ( TestedAppKind Kind ) : TaskWith!(ExceptionForwarding)
{
    static if (Kind == TestedAppKind.Daemon)
    {
        const AutoStartTestedApp = true;
        const SetupSandbox       = true;
    }
    else static if (Kind == TestedAppKind.CLI)
    {
        const AutoStartTestedApp = true;
        const SetupSandbox       = true;
    }
    else static if (Kind == TestedAppKind.Manual)
    {
        const AutoStartTestedApp = false;
        const SetupSandbox       = true;
    }
    else static if (Kind == TestedAppKind.None)
    {
        const AutoStartTestedApp = false;
        const SetupSandbox       = false;
    }

    /***************************************************************************

        Part of configuration / application context that may be necessary for
        test cases too. It gets passed to each test case during initialization.

        Refer to `turtle.app.Context.ApplicationContext` for more details.

    ***************************************************************************/

    protected Context context;

    /***************************************************************************

        Collection of configuration options that affect behaviour of test runner

    ***************************************************************************/

    protected RunnerConfig config;

    /***************************************************************************

        Used to pass turtle runner exit status flag from main task to `run`
        method so that it can be used to deduce application exit status code.

        It is merely a workaround for the fact that tango.core.Fiber doesn't
        save co-routine exit value on its own.

    ***************************************************************************/

    protected bool ok;

    /***************************************************************************

        Defines sub-package that contains test cases

    ***************************************************************************/

    protected istring test_package;

    /***************************************************************************

        Override this method to start any additional services or modify sandbox
        before any tests start.

    ***************************************************************************/

    protected void prepare ( ) { }

    /***************************************************************************

        Override this method if you use any mock environment services
        which have persistent state and need to reset all changes between
        tests.

        Will also be run once before running any test case and thus can be
        used to define initial common set of data to run test on.

        NB: this method will only be called if test case has
        `reset_env` set to 'true' in its description. In that case `reset` will
        be called after the test case.

    ***************************************************************************/

    protected void reset ( ) { }

    /***************************************************************************

        Augments overriden `reset` with sending command to control unix socket
        if it is initialized.

    ***************************************************************************/

    private void resetSync ( )
    {
        this.reset();

        if (this.context.control_socket !is null)
        {
            enforce!(TurtleException)(
                sendCommand(this.context.control_socket, "reset") == "ACK");
        }
    }

    /***************************************************************************

        Allows to temporarily disable some test cases when overridden

        Returns:
            an array of fully-qualified class names for test cases that must
            be ignored by this test runner despite being compiled in.

    ***************************************************************************/

    protected istring[] disabledTestCases ( ) { return null; }

    /***************************************************************************

        Task entry point

    ***************************************************************************/

    public final override void run ( )
    {
        // suspend once so that rest of the code will execute
        // only when eventLoop is known to be running
        theScheduler.processEvents();

        // force shutdown in the end to avoid being stuck with
        // left-over epoll events
        scope(exit)
            theScheduler.shutdown();

        .log.trace("Started test runner task");
        this.ok = this.testMain();

        // TestedApplicationBase.stop() sets a timer which sends a series of
        // signals to the app to stop it. As the scope(exit) of this method
        // kills the eventloop (thus preventing the timer from being handled),
        // we wait here until the application stops. (If all of the signals
        // fail, the test will be aborted with an assert(false), anyway.)
        if (this.context.app)
        {
            while (this.context.app.isRunning())
            {
                .log.trace("Tested application ({}) is still running",
                    this.context.app.pid());
                .wait(100_000);
            }
        }
    }

    /***************************************************************************

        The Test Runner

        It is possible to override this method to run specified actions
        several times. To do so, call `super.testMain()` each time and check
        its return value. Example:

        ---
            override public bool testMain ( )
            {
                // first attempt
                if (!super.testMain())
                    return false;

                // do nothing else for informational actions
                if (this.config.list_only)
                    return true;

                // enable extra checks and run action again:
                doSomething();
                return super.testMain();
            }
        ---

        Returns:
            test suite success status

    ***************************************************************************/

    public bool testMain ( )
    {
        try
        {
            if (this.config.delay > 0)
            {
                log.info("Test suite ready, sleeping for {} seconds before " ~
                    "running actual tests (--delay={})", this.config.delay,
                    this.config.delay);
                Thread.sleep(seconds(this.config.delay));
            }

            if (this.config.list_only)
                return Actions.listAllTests(this.config);

            this.prepareEnvironment();
            scope(exit)
            {
                // before killing tested app, unregister all know environment
                // additions to avoid irrelevant errors being printed because
                // of shutdown sequence
                turtle_env_registry.unregisterAll();

                if (this.context.app !is null)
                    this.context.app.stop();
            }

            if (this.config.test_id >= 0)
            {
                return Actions.runOne(this.config, this.context,
                    &this.resetSync);
            }

            if (this.config.memcheck)
            {
                return Actions.runTwiceCompareStats(this.config,
                    this.context, &this.resetSync,
                    this.disabledTestCases());
            }
            else
            {
                return Actions.runAll(this.config, this.context,
                    &this.resetSync, this.disabledTestCases());
            }
        }
        catch (Exception e)
        {
            log.fatal("Unexpected failure in test runner!");
            log.fatal("{}: {} ({}:{})", e.classinfo.name, e.message(), e.file, e.line);
            return false;
        }
    }

    /***************************************************************************

        Run by test task to prepare folder layout. In most cases default
        implementation is good enough but you can override it if any additional
        file operations are required. In that case, call `super.createSandbox`
        in the very beginning to create basic sandbox and switch current
        working directory to it.

    ***************************************************************************/

    protected void createSandbox ( )
    {
        // recreate folder layout and change working directory

        auto path = this.context.paths.tmp_dir;
        cstring sandbox;

        enforce!(TurtleException)(this.config.name.length == 0);

        {
            auto generated = mkdtemp(format(
                "{}/sandbox-{}-XXXXXXXX\0",
                path,
                this.context.binary
            ).dup.ptr);
            enforce!(TurtleException)(generated !is null);
            auto sandbox_path = FilePath(StringC.toDString(generated));
            this.config.name = idup(sandbox_path.file());
            sandbox = sandbox_path.toString() ~ "/";
            this.context.paths.sandbox = idup(sandbox);
            .log.trace("Created dir '{}' via mkdtemp", sandbox);
        }

        cwd(sandbox);
        shell("mkdir ./bin");
        shell("mkdir ./etc");
        shell("mkdir ./log");

        shell("install -m755 " ~ this.context.paths.binary ~ " ./bin/");

        foreach (file; this.copyFiles())
        {
            auto dst = FilePath(this.context.paths.sandbox)
                .append(file.dst_path)
                .toString();

            if (file.src_path.length)
            {
                auto dirname = shell("dirname " ~ dst);
                shell("mkdir -p " ~ dirname.stdout);
                auto src = FilePath(this.context.paths.top_dir)
                    .append(file.src_path)
                    .toString();
                shell("cp -r " ~ src ~ " " ~ dst);
            }
            else
                shell("mkdir -p " ~ dst);
        }

        log.info("Temporary sandbox created at '{}'", sandbox);
    }

    /***************************************************************************

        Defines what files/folders to copy from project directory to sandbox
        directory (if overridden).

        Copies recursively. All intermediate directories in sandbox will be
        automatically created.

        Returns:
            Array of structs containing source path (relative to project top
            directory) and destination path (relative to sandbox root).
            Source path can be empty, in that case destination path is
            interpreted as empty directory to be created.

    ***************************************************************************/

    protected CopyFileEntry[] copyFiles ( ) { return null; }

    public static struct CopyFileEntry
    {
        istring src_path;
        istring dst_path;
    }

    static if (AutoStartTestedApp)
    {
        /***********************************************************************

            Must override this method to configure how tested application
            process is to be started. Meaning of `duration` argument varies
            between `TestedAppKind.Daemon` and `TestedAppKind.CLI`.

            Params:
                duration =
                    TestedAppKind.Daemon : seconds to wait for spawned
                        process to get ready
                    TestedAppKind.CLI : seconds to wait while spawned
                        process finishes
                args  = CLI arguments for spawned process
                env   = shell environment arguments for spawned process

        ***********************************************************************/

        abstract protected void configureTestedApplication (
            out double duration, out istring[] args, out istring[istring] env );

        /***********************************************************************

            Initializes `this.context.app` to run './bin/<this.context.binary>'
            as an external process with arguments provided by
            `this.configureTestedApplication`

        ***********************************************************************/

        private void createTestedApplication ( )
        {
            double delay;
            istring[] iargs;
            istring[istring] env;
            this.configureTestedApplication(delay, iargs, env);

            // workaround until ocean Process has better const API
            auto args = new cstring[iargs.length];
            args[] = iargs[];

            auto rel_bin = "bin/" ~ this.context.binary;

            static if (Kind == TestedAppKind.Daemon)
                alias TestedDaemonApplication TestedApp;
            else
                alias TestedCliApplication TestedApp;

            this.context.app = new TestedApp(
                rel_bin,
                delay,
                this.context.paths.sandbox,
                args,
                env
            );
        }
    }

    /***************************************************************************

        Takes care of initial environment preparation that happens once before
        all test get run. This includes creating sandbox files, starting tested
        application if needed and running user prepare/reset hooks.

    ***************************************************************************/

    private void prepareEnvironment ( )
    {
        static if (SetupSandbox)
        {
            // creates all folders and copy necessary files
            this.createSandbox();
        }

        static if (AutoStartTestedApp)
        {
            this.createTestedApplication();
        }

        // user hook for starting services / processes
        this.prepare();

        static if (AutoStartTestedApp && Kind == TestedAppKind.Daemon)
        {
            // TestedAppKind.CLI is started manually in test cases
            this.context.app.start();
            log.trace("Tested application started.");
        }

        // try connecting to unix socket at path `pwd`/turtle.socket in case
        // it was created by tested app
        auto socket_path = "turtle.socket";
        if (FilePath(socket_path).exists())
        {
            .log.trace("Found {}, connecting", socket_path);
            auto addr = sockaddr_un.create(socket_path);
            this.context.control_socket = new typeof(this.context.control_socket);
            enforce!(TurtleException)(this.context.control_socket.socket() >= 0);
            auto status = this.context.control_socket.connect(&addr);
            enforce!(TurtleException)(status == 0);
        }
        else
            this.context.control_socket = null;

        // user hook to reset service state
        // normally called between tests but also runs once before to
        // ensure consistent state
        this.resetSync();
    }
}

/*******************************************************************************

    Inherit your turtle application class (the test runner) from this base class

    It automatically handles:
        - creating event loop (epoll)
        - creating test task (for wrapping async utilities in blocking API)
        - reading configuration from CLI and Makd environment variables
        - creation of sandbox folder structure
        - copying tested binary / config files into sandbox
        - discovery and running of test cases
        - resetting environment as defined by test cases

    Params:
        Kind = tested application kind. Affect how environment preparation is
            being done

*******************************************************************************/

class TurtleRunner ( TaskT ) : CliApp
{
    /***************************************************************************

        Task

    ***************************************************************************/

    protected TaskT task;

    /***************************************************************************

        Constructor

        Params:
            binary = name of tested binary (to be found in `this.bin_dir`)
            test_package = prefix for the module name(s) to look into for
                test case classes. If empty, no filter is used.

    ***************************************************************************/

    public this ( istring binary, istring test_package = "" )
    {
        .setupLogging();

        auto desc = "External functional test suite for " ~ binary;
        super("turtle", desc, v_info);

        this.task = new TaskT();

        this.task.config.test_package = test_package;

        this.task.context.binary = binary;
        this.task.context.app = null;
    }

    /***************************************************************************

        Starts the application. Should never be touched.

        Will result in `TurtleRunnerTask` being scheduled

        Params:
            args = arguments parser instance.

    ***************************************************************************/

    final public override int run ( Arguments args )
    {
        SchedulerConfiguration config;
        initScheduler(config);
        // clear exception handler to workaround regression caused by ocean
        // v3.6.0 and later which causes test suite to abort during termination
        // of the tested app because of unhandled exception:
        theScheduler.exception_handler = null;
        theScheduler.schedule(this.task);
        theScheduler.eventLoop();
        return this.task.ok ? 0 : -1;
    }

    /***************************************************************************

        Set up the command line arguments parser for the Application

        Params:
            app = application instance
            args = arguments parser to configure

    ***************************************************************************/

    protected override void setupArgs (IApplication app, Arguments args)
    {
        static if (TaskT.SetupSandbox)
        {
            args("tmpdir")
                .params(1)
                .help("Temporary directory used for preparing the sandbox");
            args("bindir")
                .params(1)
                .help("Directory where tested binary is expected to be found");
            args("projdir")
                .params(1)
                .help("Root dir of git repository");
        }

        args("list")
            .conflicts("id")
            .conflicts("filter")
            .help("Only list root test case names, run nothing");
        args("id")
            .params(1)
            .conflicts("list")
            .conflicts("filter")
            .help("Number of a test case to run (from --list)");
        args("filter")
            .params(1)
            .conflicts("id")
            .conflicts("list")
            .help("Regular expression (for a test name) to filter tests to run");
        args("verbose")
            .params(1)
            .help("0 - only error messages, " ~
                "1 - informational messages, 2 - detailed trace");
        args("delay")
            .params(1)
            .help("Sleep for N seconds between initializing sandbox and " ~
                "starting to run tests");
        args("progress")
            .params(1)
            .help("Report test progress in silent mode by printing status " ~
                "each N seconds");
        args("fatal")
            .help("Treat all test case failures as fatal");

        static if (TaskT.AutoStartTestedApp)
        {
            args("memcheck")
                .help("Runs whole test suite twice, ensuring that memory " ~
                    "usage does not change for the second run");
        }
    }

    /***************************************************************************

        Read command-line arguments for the application

        Params:
            app = application instance
            args = arguments parser to read from

    ***************************************************************************/

    protected override void processArgs (IApplication app, Arguments args)
    {
        auto verbose = args.getString("verbose");
        if (verbose.length == 0)
            verbose = Environment.get("MAKD_VERBOSE");
        if (verbose == "1")
            Log.root.level(Level.Info, true);
        if (verbose == "2")
            Log.root.level(Level.Trace, true);

        auto progress = args.getInt!(long)("progress");
        enforce(progress <= 0 || verbose.length == 0 || verbose == "0");
        this.task.config.progress_dump_interval = progress;

        this.task.config.list_only = args.exists("list");
        this.task.config.forced_fatal = args.exists("fatal");
        this.task.config.delay = args.getInt!(long)("delay");

        if (args.exists("id")) // to avoid overwriting initial -1
            this.task.config.test_id = args.getInt!(long)("id");

        if (args.exists("filter"))
            this.task.config.name_filter = args.getString("filter");

        if (args.exists("memcheck"))
            this.task.config.memcheck = true;

        static if (TaskT.SetupSandbox)
        {
            istring path;

            path = args.getString("tmpdir");
            if (path.length == 0)
                path = Environment.get("MAKD_TMPDIR");
            enforce!(TurtleException)(
                path.length > 0,
                "Must set temporary directory path (sandbox) either via " ~
                "--tmpdir argument or via MAKD_TMPDIR environment variable"
            );
            this.task.context.paths.tmp_dir = path;

            path = args.getString("bindir");
            if (path.length == 0)
                path = Environment.get("MAKD_BINDIR");
            enforce!(TurtleException)(
                path.length > 0,
                "Must set directory path with binaries either via " ~
                "--bindir argument or via MAKD_BINDIR environment variable"
            );
            this.task.context.paths.bin_dir = path;

            path = args.getString("projdir");
            if (path.length == 0)
                path = Environment.get("MAKD_TOPDIR");
            enforce!(TurtleException)(
                path.length > 0,
                "Must set root project directory either via " ~
                "--projdir argument or via MAKD_TOPDIR environment variable"
            );
            this.task.context.paths.top_dir = path;

            with (this.task.context)
            {
                paths.binary = paths.bin_dir ~ "/" ~ this.task.context.binary;
                enforce!(TurtleException)(FilePath(paths.binary).exists,
                    "File '" ~ paths.binary ~ "' not found");
            }

            log.info("Testing '{}'", this.task.context.paths.binary);
        }
    }
}

unittest
{
    // create template instances to verify compilation

    static class One : TurtleRunnerTask!(TestedAppKind.Manual)
    {
        override void prepare ( ) { }
    }

    static class Two : TurtleRunnerTask!(TestedAppKind.Daemon)
    {
        override void prepare ( ) { }

        override protected void configureTestedApplication (
            out double, out istring[], out istring[istring] ) { }
    }

    static class Three : TurtleRunnerTask!(TestedAppKind.CLI)
    {
        override void prepare ( ) { }

        override protected void configureTestedApplication (
            out double, out istring[], out istring[istring] ) { }
    }

    static class Four : TurtleRunnerTask!(TestedAppKind.None)
    {
        override void prepare ( ) { }
    }

    alias TurtleRunner!(One) RunnerOne;
    alias TurtleRunner!(Two) RunnerTwo;
    alias TurtleRunner!(Three) RunnerThree;
    alias TurtleRunner!(Four) RunnerFour;
}

/*******************************************************************************

    Utility to change working directory while trace logging new one

    Params:
        dir = new working directory

*******************************************************************************/

private void cwd ( cstring dir )
{
    .log.trace("Changing working dir to '{}'", dir);
    Environment.cwd(dir);
}
