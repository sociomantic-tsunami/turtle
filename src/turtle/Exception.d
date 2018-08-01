/*******************************************************************************

    Turtle application-specific exception classes

    Copyright: Copyright (c) 2015-2017 dunnhumby Germany GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.Exception;

import ocean.transition;

/*******************************************************************************

    Thrown if any of turtle utilities fail before getting to
    actual test cases.

*******************************************************************************/

class TurtleException : Exception
{
    /***************************************************************************

        Constructor

        Params:
            msg = exception message

    ***************************************************************************/

    this ( istring msg, istring file = __FILE__, long line = __LINE__ )
    {
        super(msg, file, line, null);
    }
}
