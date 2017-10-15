/*******************************************************************************

    Aggregates the data that configures how turtle test runner processes
    test cases

    Copyright: Copyright (c) 2015-2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.runner.internal.RunnerConfig;

import ocean.transition;

/*******************************************************************************

    Configuration aggregate

*******************************************************************************/

public struct RunnerConfig
{
    /***************************************************************************

        Defines sub-package that contains test cases

    ***************************************************************************/

    public istring test_package;

    /***************************************************************************

        name of the test suite project (to be used as suffix)

    ***************************************************************************/

    public istring name;

    /***************************************************************************

        Amount of seconds to sleep after preparing the sandbox and
        environment and before starting all the tests.

    ***************************************************************************/

    public double delay;

    /***************************************************************************

        Indicates that test runner shouldn't execute any tests and just print
        them in an ordered list

    ***************************************************************************/

    public bool list_only;

    /***************************************************************************

        If >= 0, only test with relevant id (as printed by --list output)
        will be executed.

    ***************************************************************************/

    public long test_id = -1;

    /***************************************************************************

        If not empty, used to filter test names to run.

    ***************************************************************************/

    public istring name_filter;

    /***************************************************************************

        If not 0, affects how often turtle reports its progres (seconds)

        Used in non verbose mode only too check if tests are hanging.

    ***************************************************************************/

    public long progress_dump_interval = -1;

    /***************************************************************************

        If true, all test cases will be executed as if they have `fatal` flag
        set in their `description`.

    ***************************************************************************/

    public bool forced_fatal;

    /***************************************************************************

        If set to true, whole test suite will be run twice without restarting
        tested application in between and peak memory stats compared between
        two runs.

    ***************************************************************************/

    public bool memcheck;
}
