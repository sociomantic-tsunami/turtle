/*******************************************************************************

    Copyright:
        Copyright (c) 2017 sociomantic Labs GmbH. All rights reserved

*******************************************************************************/

module integrationtest.controlsocket.main;

import ocean.transition;

import turtle.runner.Runner;
import turtle.TestCase;

version (UnitTest) {} else
int main ( istring[] args )
{
    auto runner = new TurtleRunner!(MyTurtleTests)("dummy_daemon", "",
        "controlsocket");
    return runner.main(args);
}

class MyTurtleTests : TurtleRunnerTask!(TestedAppKind.Daemon)
{
    override protected void configureTestedApplication ( out double delay,
        out istring[] args, out istring[istring] env )
    {
        delay = 0.05;
        args  = null;
        env   = null;
    }

    override public void prepare ( ) { }
    override public void reset ( ) { }
}

// do nothing, just trigger `reset`
class Dummy1 : TestCase
{
    override public void run ( )
    {
    }
}

// do nothing, just trigger `reset`
class Dummy2 : TestCase
{
    override public void run ( )
    {
    }
}

class Final : TestCase
{
    import turtle.env.ControlSocket;
    import OT = ocean.core.Test;

    override public Description description ( )
    {
        Description descr;
        descr.name = "Actual Test";
        descr.priority = -1;
        return descr;
    }

    override public void run ( )
    {
        auto response = sendCommand(this, "total");
        OT.test!("==")(response, "3"); // 2 previous tests + initial reset
    }
}
