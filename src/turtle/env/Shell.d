/*******************************************************************************

    Utilities for interacting with shell from tests

    Copyright: Copyright (c) 2016-2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.env.Shell;

import turtle.runner.Logging;
import turtle.Exception;

import ocean.transition;
import ocean.core.Enforce;
import ocean.sys.Process;
import ocean.io.device.Conduit;

/*******************************************************************************

    Exposes Process fields for status / stdin / stdout via return value
    from a `shell` call.

*******************************************************************************/

public struct ShellResult
{
    /// result of `Process.wait`
    public int status;
    /// result of `Process.stdout()`
    public mstring stdout;
    /// result of `Process.stdout()`
    public mstring stderr;
}

/*******************************************************************************

    Helper to run shell command while trace logging it

    Params:
        cmd = shell command
        validate = flag indicates if process status 0 has to be enforced

    Returns:
        ShellResult instance wrapping process data

*******************************************************************************/

public ShellResult shell ( cstring cmd, bool validate = true )
{
    log.trace("$ {}", cmd);
    ShellResult result;
    auto p = new Process(cmd, null);
    p.redirect(Redirect.Output | Redirect.Error);
    p.execute();
    result.status = p.wait().status;
    if (validate)
    {
        enforce!(TurtleException)(result.status == 0,
            idup("`" ~ cmd ~ "` has failed"));
    }

    char[1024] chunk;

    for (;;)
    {
        auto size = p.stdout.read(chunk);
        if (size == Conduit.Eof)
            break;
        result.stdout ~= chunk[0 .. size];
    }

    for (;;)
    {
        auto size = p.stderr.read(chunk);
        if (size == Conduit.Eof)
            break;
        result.stderr ~= chunk[0 .. size];
    }

    return result;
}
