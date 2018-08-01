/*******************************************************************************

    Example turtle-based test suite for `TestedAppKind.Manual`.

    It only shows concepts specific for `TestedAppKind.Manual`, refer to example
    of `TestedAppKind.Daemon` for generic test case examples.

    NB: this kind only exists to support rare and discouraged use cases and may
    be deprecated in the future.

    Copyright: Copyright (c) 2015-2017 dunnhumby Germany GmbH. All rights
        reserved.

*******************************************************************************/

module example.manual.main;

import ocean.transition;

import turtle.runner.Runner;
import turtle.TestCase;

/*******************************************************************************

    Root application class which defines how tests will be run.

    Must inherit `TurtleRunner` to get all automation features.

*******************************************************************************/

class MyTurtleRunnerTask : TurtleRunnerTask!(TestedAppKind.Manual)
{
    // can be used to log messages integrated with turtle verbose trace
    import turtle.runner.Logging;
    import turtle.application.TestedDaemonApplication;

    version (none)
    {
        /***********************************************************************

            The key point about TestedAppKind.Manual is that the user is
            responsible for starting the tested application, thus
            configureTestedApplication is not used.

        ***********************************************************************/

        override protected void configureTestedApplication ( out double delay,
            out istring[] args, out istring[istring] env ) { }
    }

    /***************************************************************************

        Because `configureTestedApplication` is not used, one has to create
        tested application manually in `prepare`.

    ***************************************************************************/

    override public void prepare ( )
    {
        log.info("Creating tested app manually");
        this.context.app = new TestedDaemonApplication(
            "bin/example",
            0.1,
            this.context.paths.sandbox,
            null,
            null
        );
    }
}

/*******************************************************************************

    You can run the resulting test suite with the `--trace` flag (or with the
    `V=1` make argument) to see more details about what actions exactly turtle
    will execute.

*******************************************************************************/

int main ( istring[] args )
{
    auto name = "example"[];
    auto test_package = "example.manual"[];

    auto runner = new TurtleRunner!(MyTurtleRunnerTask)(name, test_package);
    return runner.main(args);
}

/*******************************************************************************

    One example when `TestedAppKind.Manual` is desired is if test suite has to
    circumvent turtle default behaviour and restart daemon app between tests.

*******************************************************************************/

class TestRestart : TestCase
{
    import ocean.task.util.Timer;

    override public Description description ( )
    {
        return Description("Test with manual app control");
    }

    override public void run ( )
    {
        this.context.app.start(); // won't block because it was created as
                                  // daemon app!
        scope(exit)
        {
            this.context.app.stop(); // won't block either, need to wait:

            while ( this.context.app.isRunning() )
                wait(100_000);
        }

        // do some testing ...
    }
}
