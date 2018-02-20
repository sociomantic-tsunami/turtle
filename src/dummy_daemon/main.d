/*******************************************************************************

    Dummy daemon like application to be used in turtle own tests.

    For turtle it only matters that such application never quits prematurely
    which is achived via simple infinite loop.

    Copyright: Copyright (c) 2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

import ocean.transition;
import ocean.io.select.EpollSelectDispatcher;
import ocean.net.server.unix.UnixListener;
import ocean.text.convert.Formatter;

void main ( )
{
    auto epoll = new EpollSelectDispatcher;

    int reset_counter;

    void reset_handler ( cstring args, scope void delegate ( cstring
        response ) send_response )
    {
        ++reset_counter;
        send_response("ACK");
    }

    void count_handler ( cstring args, scope void delegate ( cstring
        response ) send_response )
    {
        send_response(format("{}", reset_counter));
    }

    auto un_listener = new UnixListener(
        "turtle.socket",
        epoll,
        [ "reset"[] : &reset_handler,
          "total" : &count_handler ]
    );

    epoll.register(un_listener);
    epoll.eventLoop();
}
