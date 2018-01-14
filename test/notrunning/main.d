/*******************************************************************************

    Tests that turtle doesn't do anything damaging in case tested CLI app was
    never started in tests.

    Copyright: Copyright (c) 2017 sociomantic labs GmbH. All rights
        reserved.

*******************************************************************************/

module test.notrunning.main;

import ocean.transition;

import turtle.runner.Runner;
import turtle.TestCase;

/// ditto
class TestedAppNotRunning : TurtleRunnerTask!(TestedAppKind.CLI)
{
    override protected void configureTestedApplication ( out double delay,
        out istring[] args, out istring[istring] env ) { }
    override public void prepare ( ) { }
    override public void reset ( ) { }
}

int main ( istring[] args )
{
    auto runner = new TurtleRunner!(TestedAppNotRunning)("dummy_cli", "");
    return runner.main(args);
}

class Dummy : TestCase
{
    override void run ( )
    {
        // normally one would to `this.context.app.start()` but this scenario
        // tests case when it got forgotten to ensure test suite terminates
        // cleanly
    }
}
