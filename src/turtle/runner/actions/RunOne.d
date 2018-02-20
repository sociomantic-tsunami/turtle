/*******************************************************************************

    Simplified test runner actions that only runs one test case

    Copyright: Copyright (c) 2015-2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.runner.actions.RunOne;

import ocean.transition;
import ocean.core.Enforce;

import turtle.Exception;
import turtle.TestCase;
import turtle.runner.Logging;
import turtle.runner.Context;
import turtle.runner.actions.List : ListOrderIterator;

// import aggregator
private struct Internal
{
    import turtle.runner.internal.Iterator : findTestCases;
    import turtle.runner.internal.DefaultTestRunner;
    import turtle.runner.internal.RunnerConfig;
}

/*******************************************************************************

    Test runner that finds one test case with a configured ID and runs only it
    (but also runs all nested test cases for that specific one)

    Params:
        config  = provides test package string
        context = passed to test cases when initializing those
        reset   = called to reset test suite state between running
            different test cases

*******************************************************************************/

public bool runOne ( ref Internal.RunnerConfig config, ref Context context,
    scope void delegate() reset )
{
    .log.info("Running only test case with ID {}", config.test_id);

    auto tests = Internal.findTestCases(config.test_package);

    // find relevant test first

    TestCase target_test = null;

    foreach (unused, index, test_case; ListOrderIterator(tests))
    {
        if (index == config.test_id)
        {
            target_test = test_case;
            break;
        }
    }

    if (target_test is null)
        throw new TurtleException("Invalid test ID");

    // now use it as sole root test case with a default
    // testing sequence so that any nested ones will be run too

    auto default_runner = new Internal.DefaultTestRunner(
        [ target_test ], context, reset );

    try
    {
        foreach (test_case; default_runner.iterator)
            default_runner.runOne(test_case);
    }
    catch (Internal.FatalFailureException e)
    {}

    return default_runner.getStats().failed == 0;
}
