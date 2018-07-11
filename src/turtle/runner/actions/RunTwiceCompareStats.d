/*******************************************************************************

    Runner action used to check O(1) memory usage

    Copyright: Copyright (c) 2017 sociomantic Labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.runner.actions.RunTwiceCompareStats;

import ocean.transition;
import ocean.core.Enforce;

import turtle.runner.Context;
import turtle.runner.internal.RunnerConfig;
import turtle.runner.actions.RunAll;
import turtle.application.TestedDaemonApplication;
import turtle.runner.Logging;

/*******************************************************************************

    Wraps `runAll` action, calling it twice and comparing memory usage
    from tested application without restarting it in between. Used for
    daemons which are required to have O(1) memory usage of given workload.

    Params:
        config  = provides test package string
        context = passed to test cases when initializing those
        reset   = called to reset test suite state between running
            different test cases
        disabled = test case names disabled by the test runner statically

*******************************************************************************/

public bool runTwiceCompareStats ( ref RunnerConfig config,
    ref Context context, scope void delegate() reset, istring[] disabled )
{
    // run twice and compare peak stats
    auto app = cast(TestedDaemonApplication) context.app;
    enforce(app !is null);

    bool result1 = runAll(config, context, reset, disabled);
    if (!result1)
        return result1;

    auto vsize1 = app.getPeakStats().vsize;
    log.info("Peak virtual memory after first run: {}", vsize1);
    log.trace("");
    log.trace("-----------------------------------------");
    log.trace("----------- END OR FIRST RUN ------------");
    log.trace("-----------------------------------------");
    log.trace("");

    bool result2 = runAll(config, context, reset, disabled);
    auto vsize2 = app.getPeakStats().vsize;
    log.info("Peak virtual memory after second run: {}", vsize2);

    enforce!(">=")(vsize1, vsize2);

    return result2;
}
