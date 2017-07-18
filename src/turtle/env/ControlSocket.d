/*******************************************************************************

    Convenience helpers for working with unix socket connecting a test suite and
    a tested application.

    Copyright: Copyright (c) 2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.env.ControlSocket;

import ocean.transition;
import ocean.core.Enforce;
import ocean.sys.socket.UnixSocket;

import turtle.TestCase;

/*******************************************************************************

    Helper unifying write + recv pair in a single blocking utility

    Params:
        sock = already connected unix socket to use
        command = command to send
        args = optional command arguments

    Returns:
        response value allocated as new string, 1024 bytes max

*******************************************************************************/

public istring sendCommand ( UnixSocket sock, cstring command, cstring args = "")
{
    enforce(sock !is null);

    sock.write(command ~ " " ~ args ~ "\n");
    static char[1024] buffer;
    auto count = sock.recv(buffer, 0);
    return idup(buffer[0 .. count]);
}

/// ditto
public istring sendCommand ( TestCase tc, cstring command, cstring args = "")
{
    auto sock = tc.context.control_socket;
    return sendCommand(sock, command, args);
}
