/*******************************************************************************

    Example turtle-based test suite for `TestedAppKind.CLI`.

    It only shows concepts specific for `TestedAppKind.CLI`, refer to example of
    `TestedAppKind.Daemon` for generic test case examples.

    Copyright: Copyright (c) 2015-2017 sociomantic labs GmbH. All rights
        reserved.

*******************************************************************************/

module example.cli.main;

import ocean.transition;

import turtle.runner.Runner;
import turtle.TestCase;

/*******************************************************************************

    Root application class which defines how tests will be run.

    Must inherit `TurtleRunner` to get all automation features.

*******************************************************************************/

class MyTurtleRunnerTask : TurtleRunnerTask!(TestedAppKind.CLI)
{
    /***************************************************************************

        This method must be overridden to define how the tested application
        process is to be started.

    ***************************************************************************/

    override protected void configureTestedApplication ( out double timeout,
        out istring[] args, out istring[istring] env )
    {
        timeout = 0.5; // wait time before tested app will get killed
        args  = [ "--message" ];  // any CLI arguments
        env   = null;  // any environment variables
    }

    /***************************************************************************

        No preparations are needed in this example but overriding this method
        is mandatory.

    ***************************************************************************/

    override public void prepare ( )
    {
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
    auto test_package = "example.cli"[];

    auto runner = new TurtleRunner!(MyTurtleRunnerTask)(name, test_package);
    return runner.main(args);
}

/*******************************************************************************

    Example test case that spawns CLI app and ensures expected output to the
    console.

*******************************************************************************/

class TestCLI : TestCase
{
    import ocean.core.Test;
    import turtle.application.TestedCliApplication;

    override public Description description ( )
    {
        return Description("Checking stdout of tested app");
    }

    override public void run ( )
    {
        // unfortunately, generic runtime nature of turtle does not allow to
        // easily track if used app is CLI or Daemon one, thus casting is
        // required to use CLI specific methods like `last_stdout`.
        auto cli_app = cast(TestedCliApplication) this.context.app;

        // will block until app terminates or gets killed by a timeout
        cli_app.start();
        test!("==")(cli_app.last_stdout(), "Test Message\n");

        // extra CLI arguments will be appended to ones defined in
        // `configureTestedApplication`
        cli_app.start([ "--irrelevant" ]);
        test!("==")(cli_app.last_stdout(), "Test Message\n");
    }
}
