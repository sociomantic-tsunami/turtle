/*******************************************************************************

    Convenience helpers for working with unix socket connecting a test suite and
    a tested application.

    Turtle will check if tested application has created file named
    "turtle.socket" in the sandbox root and try connecting to it if present.
    Applications implementing "turtle.socket" support must provide handler for
    at least one command, "reset", which will be sent after each time test
    runner reset() method is called. The handler must respond with "ACK" string,
    even if handler implementation is no-op otherwise - this is required so that
    turtle won't continue with running tests until app is ready.

    Any other arbitrary command handlers can be implemented in the application
    and triggered via this module.

    NB: it is higlhy recommended to create "turtle.socket" in the tested
    application only once the application has completed all required start-up
    logic and is in a testable state. It is planned to eventually use creation
    of this file as a replacement of current fixed startup wait delay.

    Copyright: Copyright (c) 2017 dunnhumby Germany GmbH. All rights reserved

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
