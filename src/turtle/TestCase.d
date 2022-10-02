/*******************************************************************************

    Base for all turtle test cases

    Copyright: Copyright (c) 2015-2017 dunnhumby Germany GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.TestCase;

import ocean.transition;

/*******************************************************************************

    Inherit from this class to get automatic discovery of your test cases
    and simplified environment setup when used together with
    `turtle.runner.Runner`.

*******************************************************************************/

abstract class TestCase
{
    import turtle.runner.Context;

    /***************************************************************************

        This field contains all application information that may be necessary
        to execute test cases. Such information is separated into dedicated
        context struct to avoid circular dependency with `TurtleRunner`.

        Refer to `turtle.runner.Context` for more details.

    ***************************************************************************/

    public Context context;

    /***************************************************************************

        `TurtleRunner` automatically discovers all TestCase-derived classes and
        instantiates them via `ClassInfo.create()`.

        However, `ClassInfo.create()` can only create classes with default
        constructors. To be able to initialize necessary context, `TurtleRunner`
        will instead call this method after construction.

        It should never be called manually.

        Params:
            context = host turtle application context

    ***************************************************************************/

    public final void init ( Context context )
    {
        this.context = context;
    }

    /***************************************************************************

        Contains all information about this test case that host test runner
        needs to know to process it properly.

    ***************************************************************************/

    public static struct Description
    {
        /// name to use in trace output
        string name;

        /// if set to 'true', host will call `TurtleRunner.reset()` after
        /// running this test case. This is the default option to discourage
        /// sharing state between test cases
        bool    reset_env  = true;

        /// if set to 'true, failing this test will cause termination of whole
        /// test suite without running any other tests
        bool    fatal      = false;

        /// used to sort all test cases - tests with higher `priority` value
        /// will be run first
        int     priority   = 0;
    }

    /***************************************************************************

        Override this method if you need to set any description fields.

        Returns:
            Description for this test case. The base implementation returns a
            default description instance.

    ***************************************************************************/

    public Description description ( )
    {
        return Description(this.classinfo.name);
    }

    /***************************************************************************

        Called before running the test, usually no-op.

        NB: This method is NOT for preparing fakenode data, that should be done
        inside `run()`.

        Method designed to be overridden in custom base classes in case of some
        custom hook needs to be called before each derived test. Alternative
        would be to define base `run()` and call `super.run()` in the beginning
        of each test case which would be much more error-prone.

        Any exception thrown inside `prepare` is considered a test suite
        internal error and not test case failure, resulting in immediate
        termination.

    ***************************************************************************/

    public void prepare ( ) { }

    /***************************************************************************

        Called after running the test, no-op by default. Useful for defining
        custom base class for test cases.

    ***************************************************************************/

    public void cleanup ( ) { }

    /***************************************************************************

        Define the test by overriding this method. Use `ocean.core.Test.test`
        to check for desired conditions.

    ***************************************************************************/

    public abstract void run ( );

    /***************************************************************************

        Used in sorting. Don't touch this.

    ***************************************************************************/

    mixin (genOpCmp(`
        {
            auto rhs_tc = cast(TestCase) rhs;
            auto this_tc = cast(TestCase) this;
            auto lp = this_tc.description().priority;
            auto rp = rhs_tc.description().priority;
            return
                lp < rp ? 1 :
                    lp == rp ? 0 :
                        -1;
        }
    `));
}

/*******************************************************************************

    Special kind of TestCase (recognized by turtle runner) that spawn multiple
    nested test cases that can be created at runtime.

    For all "normal" test cases using non-nested version is still recommended
    because it is easier to maintain and extend with new cases.

*******************************************************************************/

abstract class MultiTestCase : TestCase
{
    /***************************************************************************

        Turtle runner will call this method to get array of nested test cases,
        which can also possibly be MultiTestCase instance if needed.

        Returns:
            array of test cases to run as part of the current one

    ***************************************************************************/

    public abstract TestCase[] getNestedCases ( );

    /***************************************************************************

        In most MultiTestCase instances you don't need to have own `run()` so
        it is overridden with empty implementation for convenience. One can
        still provide non-empty implementation if needed, it will be called
        after all nested cases are finished.

    ***************************************************************************/

    override public void run () { }
}
