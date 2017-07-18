/*******************************************************************************

    Dummy daemon like application to be used in turtle own tests.

    For turtle it only matters that such application never quits prematurely
    which is achived via simple infinite loop.

    Copyright: Copyright (c) 2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

static import core.thread;
import ocean.core.Time;

void main ( )
{
    while (true)
    {
        core.thread.Thread.sleep(seconds(1));
    }
}
