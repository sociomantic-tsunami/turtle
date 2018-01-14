module test.order.main;

/*******************************************************************************

    Imports

*******************************************************************************/

import turtle.runner.Runner;
import turtle.TestCase;

import OT = ocean.core.Test;

import ocean.transition;

/*******************************************************************************

    Test runner with no external app and all default configuration

*******************************************************************************/

class VerifyTestOrder : TurtleRunnerTask!(TestedAppKind.None)
{
    override istring[] disabledTestCases ( )
    {
        return [ "test.order.main.DisabledTest" ];
    }
}

/*******************************************************************************

    Defines four tests that must be run in strict order and with third test
    in sequence marked as fatal so that last one must be never reached. Order
    of tests is verified by checking / incrementing global counter.

*******************************************************************************/

long total_tests_run;

int main ( istring[] args )
{
    auto runner = new TurtleRunner!(VerifyTestOrder)("", "");
    auto status = runner.main(args);
    OT.test!("!=")(status, 0);
    OT.test!("==")(total_tests_run, 3);
    return 0;
}

class Test1 : TestCase
{
    override public Description description ( )
    {
        Description dscr = super.description();
        dscr.priority = 5;
        return dscr;
    }

    override public void run ( )
    {
        total_tests_run++;
        OT.test!("==")(total_tests_run, 1);
    }
}

class Test2 : TestCase
{
    override public Description description ( )
    {
        Description dscr = super.description();
        dscr.priority = 4;
        return dscr;
    }

    override public void run ( )
    {
        total_tests_run++;
        OT.test!("==")(total_tests_run, 2);
    }
}

class Test3_Fatal : TestCase
{
    override public Description description ( )
    {
        Description dscr = super.description();
        dscr.priority = 3;
        dscr.fatal = true;
        return dscr;
    }

    override public void run ( )
    {
        total_tests_run++;
        OT.test!("==")(total_tests_run, 3);
        // There is no easy way to suppress trace log output for failing
        // test condition so just saying clearly that it can be ignored:
        OT.test(false, "This condition is expected to fail and won't result " ~
            "in whole test suite failing");
    }
}

class Test4_NeverRuns : TestCase
{
    override public Description description ( )
    {
        Description dscr = super.description();
        dscr.priority = 2;
        return dscr;
    }

    override public void run ( )
    {
        total_tests_run++;
        OT.test(false);
    }
}

class DisabledTest : TestCase
{
    override public void run ( )
    {
        OT.test(false);
    }
}
