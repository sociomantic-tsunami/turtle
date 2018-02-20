/*******************************************************************************

    Prints list of root test cases instead of running them

    Copyright: Copyright (c) 2015-2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.runner.actions.List;

import ocean.transition;
import ocean.io.Stdout;
import ocean.text.Util;

import turtle.TestCase;
import turtle.runner.Logging;
import turtle.runner.Context;

// import aggregator
private struct Internal
{
    import turtle.runner.internal.Iterator : findTestCases, TestCaseIterator;
    import turtle.runner.internal.RunnerConfig;
}

/*******************************************************************************

    Prints list of root test cases (grouped by priority) instead of
    running them.

    Params:
        config = provides test package string

    Returns:
        true (this action never fails)

*******************************************************************************/

public bool listAllTests ( ref Internal.RunnerConfig config )
{
    auto tests = Internal.findTestCases(config.test_package);

    // iterate root test cases separately to check and print the priority

    long last_priority = long.max;
    size_t index = 0;

    foreach (root_case; tests)
    {
        if (root_case.description().priority != last_priority)
        {
            last_priority = root_case.description().priority;
            Stdout.formatln("Priority: {}", last_priority);
        }

        auto iterator = ListOrderIterator([ root_case ]);

        foreach (indent, _, test_case; iterator)
        {
            Stdout.formatln("{}[{}] {}", repeat("\t", indent + 1), index,
                test_case.description().name);
            index++;
        }
    }

    return true;
}

/*******************************************************************************

    Modified iterator built on top of TestCaseIterator which iterates all test
    cases in print-friendly order (parent first, nested follow) as opposed to
    depth-first iteration of generic TestCaseIterator.

    It also provides nesting level and index as loop variables.

    ListOrderIterator is exposed as public to be reused by any other actions
    that are related to `--list` and must use same order.

*******************************************************************************/

public struct ListOrderIterator
{
    /***************************************************************************

        Array of root test cases to iterate over

    ***************************************************************************/

    private TestCase[] tests;

    /***************************************************************************

        Iteration method

        Params:
            dg = loop delegate which will be provided with 3 arguments - depth
                of nesting for current test, total index of iteration and
                actual test case

    ***************************************************************************/

    int opApply ( scope int delegate (ref size_t nesting, ref size_t index,
        ref TestCase test) dg )
    {
        size_t nesting = 0;
        size_t i = 0;

        auto iterator = Internal.TestCaseIterator((&this).tests);

        iterator.nesting_hook = (bool enters) {
            if (enters)
                ++nesting;
            else
                --nesting;
        };

        int result = 0;

        iterator.prepare_hook = (TestCase test_case) {
            result = dg(nesting, i, test_case);
            ++i;
        };

        foreach (unused; iterator)
        {
            // all job is done in prepare_hook
            // (so that MultiTestCase gets listed before its nested cases)
            if (result)
                return result;
        }

        return 0;
    }
}
