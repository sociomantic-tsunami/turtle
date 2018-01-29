/*******************************************************************************

    Example turtle-based test suite for `TestedAppKind.Daemon`.

    Copyright: Copyright (c) 2015-2017 sociomantic labs GmbH. All rights
        reserved.

*******************************************************************************/

module example.daemon.main;

import ocean.transition;

import turtle.runner.Runner;
import turtle.TestCase;

/*******************************************************************************

    Root application class which defines how tests will be run.

    Must inherit `TurtleRunner` to get all automation features.

*******************************************************************************/

class MyTurtleRunnerTask : TurtleRunnerTask!(TestedAppKind.Daemon)
{
    // can be used to log messages integrated with turtle verbose trace
    import turtle.runner.Logging;

    /***************************************************************************

        This method can be overridden to specify additional files
        to copy into the test sandbox.

        Each element in returned array must be a struct with two fields - path
        relative to project root of file to copy and destination path relative
        to sandbox root.

    ***************************************************************************/

    override public CopyFileEntry[] copyFiles ( )
    {
        return [
            CopyFileEntry("doc/etc/example.ini", "etc/example.ini")
        ];
    }

    /***************************************************************************

        This method must be overridden to define how the tested application
        process is to be started.

    ***************************************************************************/

    override protected void configureTestedApplication ( out double delay,
        out istring[] args, out istring[istring] env )
    {
        delay = 0.5;  // wait time between starting the app and running tests
        args  = null; // any CLI arguments
        env   = null; // any environment variables
    }

    /***************************************************************************

        The `prepare` method gets called after all filesystem preparations are
        finished. It can be used to start addition mock environment services
        that are expected by tested app or do additional manipulations with the
        sandbox.

    ***************************************************************************/

    override public void prepare ( )
    {
        log.info("Preparing environment and the sandbox");
    }


    /***************************************************************************

        This method gets called each time a test case requests that the state of
        the test suite environment be reset. Clean any custom state you may have
        in environment mocks / sandbox here.

    ***************************************************************************/

    override public void reset ( )
    {
        log.info("Resetting everything");
    }
}

/*******************************************************************************

    If no custom CLI argument handling is needed, one can simply use base
    `TurtleRunner` class instantiated with your runner task type, calling
    its `main` method directly.

    Alternatively, one can also inherit from `TurtleRunner` and customize it
    too, but that is more advanced topic not covered in this example.

*******************************************************************************/

int main ( istring[] args )
{
    auto name = "example"[];
    auto test_package = "example.daemon"[];

    auto runner = new TurtleRunner!(MyTurtleRunnerTask)(name, test_package);
    return runner.main(args);
}

/*******************************************************************************

    Example test case that will cause early termination upon failure because
    it is described as "fatal".

    Note that despite the fact that this test comes first in the module, it
    will actually be run last (as the class name suggests) because it has a
    lower priority value.

*******************************************************************************/

class TestLast : TestCase
{
    import ocean.core.Test;

    override public Description description ( )
    {
        Description dscr;
        dscr.name      = "Very important test";
        dscr.fatal     = true;
        dscr.priority  = 0;
        return dscr;
    }

    override public void run ( )
    {
        // test failure is indicated by throwing an exception
        // any exception class is allowed
        test(false, "This is expected to fail and terminate");
    }
}

/*******************************************************************************

    Another example test case. This will be run first and won't cause the
    termination of the whole test suite on failure. Turtle will simply count
    such non-fatal test failures and print them in the end.

*******************************************************************************/

class Test1 : TestCase
{
    import ocean.core.Test;

    override public Description description ( )
    {
        Description dscr;
        dscr.name      = "Non-critical test";
        dscr.fatal     = false;
        dscr.priority  = 1;
        return dscr;
    }

    override public void run ( )
    {
        test(false, "This is expected to fail and continue");
    }
}

/*******************************************************************************

    Example of multi-test that consists from multiple nested test cases that
    get created at runtime. This example is very artificial and only shows how
    this feature is processed by TurtleRunner.

    To see when this feature is applicable, check the documentation of
    `MultiTestCase`

*******************************************************************************/

class Test2 : MultiTestCase
{
    import ocean.text.convert.Formatter;
    import ocean.core.Test;

    static class NestedTest : TestCase
    {
        int num;

        this ( int num )
        {
            this.num = num;
        }

        override public Description description ( )
        {
            return Description(format("Nested test #{}", this.num), false, false, 0);
        }

        override public void run ( )
        {
            test!("==")(3, 4);
        }
    }

    override public Description description ( )
    {
        Description dscr;
        dscr.name      = "Example of test case consisting from many nested " ~
            "ones (created at runtime)";
        dscr.fatal     = false;
        dscr.priority  = 1;
        return dscr;

    }

    override TestCase[] getNestedCases ( )
    {
        TestCase[] retval;
        for (int i = 1; i < 4; ++i)
            retval ~= new NestedTest(i);
        return retval;
    }
}

/*******************************************************************************

    Control unix socket usage example. Requires support from tested application
    to pass.

*******************************************************************************/

class Test3 : TestCase
{
    import ocean.core.Test;
    import turtle.env.ControlSocket : sendCommand;

    override public Description description ( )
    {
        Description dscr;
        dscr.name      = "Unix socket usage example";
        dscr.fatal     = false;
        dscr.priority  = 1;
        return dscr;
    }

    override public void run ( )
    {
        auto response = sendCommand(this, "ping", "42");
        test!("==")(response, "pong 42");
    }
}
