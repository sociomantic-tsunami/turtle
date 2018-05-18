/*******************************************************************************

    Provides facilities to find all test case classes in the binary and iterate
    over them in generic way while respecting nested test cases.

    Copyright: Copyright (c) 2015-2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.runner.internal.Iterator;

import ocean.transition;
import ocean.core.Array;

import turtle.TestCase;
import turtle.runner.Logging;

/*******************************************************************************

    Iterates all found test cases, including ones provided by MultiTestCase
    and calls custom handler for each. All handlers are optional and can be
    kept `null`.

    ---
    auto iterator = new TestCaseIterator(root_test_cases);

    // setup optional hooks
    iterator.prepare_hook = () {
        // runs before each test
    };
    iterator.nesting_hook = (bool enters) {
        if (enters)
            increaseLogIndent();
        else
            decreaseLogIndent();
    };

    // use
    foreach (test_case; iterator)
    {
        test_case.run();
    }
    ---

*******************************************************************************/

public struct TestCaseIterator
{
    /***************************************************************************

        Array of root test cases to start iteration from. If some elements
        are of MultiTestCase base class, iteration will continue recursively
        into nested ones.

    ***************************************************************************/

    private TestCase[] test_cases;

    /***************************************************************************

        If not null, will be called after fully processing each test cases
        (including nested ones).

        Params:
            test_case = test case instance that has just been processed

    ***************************************************************************/

    public void delegate(TestCase test_case) reset_hook;

    /***************************************************************************

        If not null, will be called before running nested test cases (if any)
        or before running main `opApply` delegate otherwise.

        Params:
            test_case = test case instance that is to be processed

    ***************************************************************************/

    public void delegate(TestCase test_case) prepare_hook;

    /***************************************************************************

        If not null, will be called before/after iterating nested test cases
        if there are any and not called otherwise at all.

        Params:
            enters = boolean flag, if set to `true`, this means the hook is
                called before

    ***************************************************************************/

    public void delegate(bool enters) nesting_hook;

    /***************************************************************************

        Actual iterator

        Params:
            dg = foreach body

        Returns:
            loop status code

    ***************************************************************************/

    public int opApply ( scope int delegate(ref TestCase) dg )
    {
        foreach ( test_case; (&this).test_cases )
        {
            if ((&this).prepare_hook !is null)
                (&this).prepare_hook(test_case);

            auto multi = cast(MultiTestCase) test_case;
            if (multi !is null)
            {
                if ((&this).nesting_hook !is null)
                    (&this).nesting_hook(true);

                auto status = TestCaseIterator(
                    multi.getNestedCases(),
                    (&this).reset_hook,
                    (&this).prepare_hook,
                    (&this).nesting_hook
                ).opApply(dg);

                if (status)
                    return status;

                if ((&this).nesting_hook !is null)
                    (&this).nesting_hook(false);
            }

            auto status = dg(test_case);

            if ((&this).reset_hook !is null)
                (&this).reset_hook(test_case);

            if (status)
                return status;
        }

        return 0;
    }
}

/*******************************************************************************

    Uses runtime reflection to find all class definitions that inherit
    `TestCase` and create one object of each such class.

    Most commonly used to get list of test case to supply to `TestCaseIterator`

    Params:
        test_package = only check module which have fully qualified name
            starting with this string (usually it is a package name). Empty
            string implies no filter.

    Returns:
        array of found test cases, no specific order of element

*******************************************************************************/

public TestCase[] findTestCases(istring test_package)
{
    TestCase[] tests;

    foreach (minfo; ModuleInfo)
    {
        if (!minfo)
            continue;

        if (!minfo.name.startsWith(test_package))
            continue;

        foreach (cinfo; minfo.localClasses)
        {
            // don't try to interpret MultiTestCase base as test case
            if (cinfo is MultiTestCase.classinfo)
                continue;

            auto base = cinfo.base;

            while (base !is null && base != TestCase.classinfo)
                base = base.base;

            if (base !is null)
            {
                auto test_case = cast(TestCase) cinfo.create();
                if (test_case is null)
                {
                    .log.error(
                        "Found an invalid test case class '{}' which doesn't " ~
                            "have the default constructor defined.",
                        cinfo.name
                    );
                    .increaseLogIndent();
                    .log.error("Move it outside of test case package or add " ~
                        "the default constructor");
                    .decreaseLogIndent();
                }
                else
                    tests ~= test_case;
            }
        }
    }

    sort(tests); // sorts by `TestCase.description().priority`
    return tests;
}
