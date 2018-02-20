/*******************************************************************************

    Independent implementation of test running operation order that can be
    reused from various parts of turtle.runner.actions with any desired
    test set.

    Copyright: Copyright (c) 2015-2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.runner.internal.DefaultTestRunner;

import ocean.transition;

import turtle.TestCase;
import turtle.runner.Logging;
import turtle.runner.Context;
import turtle.runner.internal.Iterator;

/*******************************************************************************

    Sets up TestCaseIterator to run over all provided test cases using
    standardized logging and environment preparation sequence.

    Provides default `runOne` method to be used inside a loop body when
    iterating over `this.iterator` - different runner actions may have
    additional code before running it (i.e. test name/id checks).

    Example:
    ---
        // creates an iterator wrappper with default set of hooks
        auto default_runner = new DefaultTestRunner(tests, () { env.clear() });
        // possible to remove/change some hooks:
        default_runner.iterator.prepare_hook = null;
        foreach (test; default_runner.iterator)
        {
            // possible to add extra logs/checks before running each test
            default_runner.runOne(test, context);
        }
    ---

*******************************************************************************/

public final class DefaultTestRunner
{
    /***************************************************************************

        Stores amount of tests run and how many of those have failed

    ***************************************************************************/

    private TestStats stats;

    /***************************************************************************

        Data shared between runner and tests. Set once in constructor

    ***************************************************************************/

    private Context context;

    /***************************************************************************

        Callback provided by user of this class to reset full test suite
        environment

    ***************************************************************************/

    private void delegate() env_reset_dg;


    /***************************************************************************

        Wrapped test iterator instance. Public so that any external code
        can modify default hooks if needed.

    ***************************************************************************/

    public TestCaseIterator iterator;

    /***************************************************************************

        Constructor

        Params:
            tests    = array of root test cases to run
            context  = data shared between runner and tests
            reset_dg = delegate to run when resetting the environment is needed

    ***************************************************************************/

    this ( TestCase[] tests, Context context, scope void delegate() reset_dg)
    {
        assert(tests.length);
        assert(reset_dg !is null);

        this.iterator     = TestCaseIterator(tests);
        this.context      = context;
        this.env_reset_dg = reset_dg;
        this.reset();
    }

    /***************************************************************************

        Getter for accumulated stats from all tests being run via
        `this.runOne`

    ***************************************************************************/

    public TestStats getStats ( )
    {
        return this.stats;
    }

    /***************************************************************************

        Resets stats and iterator hooks

    ***************************************************************************/

    public void reset ( )
    {
        this.stats = TestStats.init;

        this.iterator.prepare_hook = &this.defaultPrepareHook;
        this.iterator.reset_hook = &this.defaultResetHook;

        // doesn't need `this` context
        this.iterator.nesting_hook = (bool enters) {
            if (enters)
                .increaseLogIndent();
            else
                .decreaseLogIndent();
        };
    }

    /***************************************************************************

        Defines processing order for a single test case. Must be used with
        TestCaseIterator to work correctly with MultiTestCase.

        Stats for processed tests can be retrieved via `this.getStats()`

        Params:
            test_case = test to run

    ***************************************************************************/

    public void runOne ( TestCase test_case )
    {
        auto desc = test_case.description();

        increaseLogIndent();
        scope(exit)
            decreaseLogIndent();

        scope(exit)
            test_case.cleanup();

        try
        {
            test_case.run();
        }
        catch (Exception e)
        {
            this.stats.failed++;

            // if --verbose=0 names of executed tests are not normally
            // printed, thus it needs to be done again via log.error
            // to give readable failure context to developer
            if (.log.level == Level.Error)
            {
                decreaseLogIndent();
                .log.error("Testing '{}' ...", desc.name);
                increaseLogIndent();
            }

            .log.error("FAIL at {}:{}", e.file, e.line);
            increaseLogIndent();
            .log.error("({})", getMsg(e));
            .log.error("Sandbox path was '{}'", context.paths.sandbox);
            decreaseLogIndent();

            if (desc.fatal)
            {
                .log.info("marked as fatal, terminating");
                throw new FatalFailureException(this.stats);
            }
        }
    }

    /***************************************************************************

        Default implementation of TestCaseIterator prepare_hook

    ***************************************************************************/

    private void defaultPrepareHook ( TestCase test_case )
    {
        this.stats.total++;
        test_case.init(this.context);
        test_case.prepare();
    }

    /***************************************************************************

        Default implementation of TestCaseIterator reset_hook

    ***************************************************************************/

    private void defaultResetHook ( TestCase test_case )
    {
        if (test_case.description().reset_env)
        {
            .log.trace("resetting the environment requested");
            this.env_reset_dg();
        }
    }
}

/*******************************************************************************

    Exception class that is used to indicate that one of fatal test cases
    (as defined by its `description`) has failed and test suite must terminate
    at once

*******************************************************************************/

public class FatalFailureException : Exception
{
    /***************************************************************************

        Contains collected stats from the point when fatal test failure was
        detected (counting the fatal one too)

    ***************************************************************************/

    public TestStats stats;

    /***************************************************************************

        Constructor

        Params:
            stats = see `this.stats`

    ***************************************************************************/

    this ( TestStats stats, istring file = __FILE__, int line = __LINE__ )
    {
        this.stats = stats;
        super ("Test case that was marked as fatal failed", file, line);
    }
}

/*******************************************************************************

    Simple wrapper struct used to aggregate statistics about how many
    test have been run and how many of those have failed.

    Should only be used as return value from `DefaultTestRunner` thus private.

*******************************************************************************/

private struct TestStats
{
    long total;
    long failed;
}
