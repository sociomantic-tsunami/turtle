/*******************************************************************************

    Part of configuration / test runner context that may be necessary for
    test cases too. It gets passed to each test case during initialization.

    Copyright: Copyright (c) 2015-2017 dunnhumby Germany GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.runner.Context;

/*******************************************************************************

    Aggregates data for shared application context

*******************************************************************************/

struct Context
{
    import turtle.application.model.TestedApplicationBase;

    import ocean.transition;
    import ocean.sys.socket.UnixSocket;

    /// tested application (external process)
    TestedApplicationBase app;
    /// name of the tested binary (without dir path)
    istring binary;
    /// socket for communicating with tested application
    UnixSocket control_socket;

    static struct EnvPaths
    {
        /// working directory for tested application
        istring sandbox;
        /// fully-qualified path to tested binary
        istring binary;
        /// directory which contains all temporaries including sandbox
        istring tmp_dir;
        /// directory which contains `this.binary`
        istring bin_dir;
        /// root project directory
        istring top_dir;
    }

    /// path configuration relevant to test cases
    EnvPaths paths;
}
