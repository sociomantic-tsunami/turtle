/*******************************************************************************

    Dummy CLI app to be used in turtle own tests

    Copyright: Copyright (c) 2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module dummy_cli.main;

import ocean.io.Stdout;

version (UnitTest) {} else
void main ( )
{
    Stdout.formatln("{}", "Hello, World!");
}
