/*******************************************************************************

    Default test runner action which finds and runs all test cases defined
    in the test binary.

    Copyright: Copyright (c) 2015-2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.runner.actions.RunAll;

import ocean.transition;
import ocean.text.regex.PCRE;
import ocean.io.Stdout;
import ocean.math.IEEE;
import ocean.time.Clock;

import turtle.TestCase;
import turtle.runner.Logging;
import turtle.runner.Context;

// import aggregator
private struct Internal
{
    import turtle.runner.internal.Iterator : findTestCases;
    import turtle.runner.internal.DefaultTestRunner;
    import turtle.runner.internal.RunnerConfig;
}

/*******************************************************************************

    Default test runner action which finds and runs all test cases defined
    in the test binary.

    Params:
        config  = provides test package string
        context = passed to test cases when initializing those
        reset   = called to reset test suite state between running
            different test cases
        disabled = test case names disabled by the test runner statically

*******************************************************************************/

public bool runAll ( ref Internal.RunnerConfig config, ref Context context,
    scope void delegate() reset, istring[] disabled )
{
    PCRE.CompiledRegex regex;

    auto last_progress_report = Clock.now.span.seconds;

    if (config.name_filter)
    {
        .log.info("Running only test cases which name matches regular " ~
            "expression '{}'", config.name_filter);
        regex = (new PCRE).new CompiledRegex;
        regex.compile(config.name_filter);
    }

    auto tests = Internal.findTestCases(config.test_package);
    // TODO: this code could be replaced by the filter() function from
    // ocean.core.array.Transformation (which is currently broken when used with
    // arrays of references).
    TestCase[] filtered;
    filter_loop: foreach (test; tests)
    {
        foreach (name; disabled)
            if (test.classinfo.name == name)
                continue filter_loop;

        filtered ~= test;
    }
    tests = filtered;

    if (tests.length == 0)
    {
        .log.error("No test cases found, aborting the test suite");
        return false;
    }

    auto default_runner = new Internal.DefaultTestRunner(tests, context, reset);

    // enhance prepare hook with console output
    auto default_prepare = default_runner.iterator.prepare_hook;
    default_runner.iterator.prepare_hook = (TestCase test_case) {
        auto desc = test_case.description();
        if (regex && !regex.match(desc.name))
            .log.trace("Skipping '{}'", desc.name);
        else
            .log.info("Testing '{}' ...", test_case.description().name);
        default_prepare(test_case);
    };

    // don't reset anything if test is not run
    auto default_reset = default_runner.iterator.reset_hook;
    default_runner.iterator.reset_hook = (TestCase test_case) {
        auto desc = test_case.description();
        if (!regex || regex.match(desc.name))
            default_reset(test_case);
    };

    size_t ignored = 0;
    size_t progress = 0;

    try
    {
        foreach (test_case; default_runner.iterator)
        {
            ++progress;

            auto desc = test_case.description();

            if (regex && !regex.match(desc.name))
                ++ignored;
            else
            {
                default_runner.runOne(test_case);

                // if --fatal flag is provided via CLI, any test failure must
                // be treated as fatal:

                if (config.forced_fatal && default_runner.getStats().failed > 0)
                {
                    throw new Internal.FatalFailureException(
                        default_runner.getStats());
                }
            }

            if (config.progress_dump_interval > 0)
            {
                if (Clock.now.span.seconds - last_progress_report
                        > config.progress_dump_interval)
                {
                    last_progress_report = Clock.now.span.seconds;
                    Stdout.formatln("Running.. {} tests completed so far",
                        progress).flush();
                }
            }
        }
    }
    catch (Internal.FatalFailureException e)
    {
        // stats stored in `default_runner.getStats()`
    }

    // report results

    .log.info("{} tests ignored because of --filter", ignored);

    if (default_runner.getStats().failed > 0)
    {
        .log.info("{} out of {} test cases have failed",
            default_runner.getStats().failed, default_runner.getStats().total);
        return false;
    }
    else
    {
        .log.info("All {} tests succeeded", default_runner.getStats().total);
        return true;
    }
}
