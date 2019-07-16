/*******************************************************************************

    Simple logging utility used for test reporting

    Copyright: Copyright (c) 2015-2017 sociomantic labs GmbH. All rights reserved

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.runner.Logging;

import ocean.transition;
import ocean.util.log.Logger;
import ocean.util.log.AppendConsole;
import ocean.util.log.Appender;
import ocean.util.log.Event;

public import ocean.util.log.Logger : Level;

/*******************************************************************************

    Shared log instance used in turtle applications

*******************************************************************************/

public Logger log;

/*******************************************************************************

    Called to increase indentation to all output logged through SimpleLayout

*******************************************************************************/

public void increaseLogIndent ( )
{
    SimpleLayout.indent_count++;
}

/*******************************************************************************

    Called to decrease indentation to all output logged through SimpleLayout

*******************************************************************************/

public void decreaseLogIndent ( )
{
    SimpleLayout.indent_count--;
}

/*******************************************************************************

    Function to be called from runner constructor to initialize turtle
    logging system. It is not done in module constructor to make sure it runs
    _after_ all module constructors and is last one to modify root logger.

*******************************************************************************/

public void setupLogging ( )
{
    Log.root.clear();
    auto appender = new AppendConsole;
    appender.layout(new SimpleLayout);
    Log.root.add(appender);
    Log.root.level(Level.Error, true);
    log = Log.lookup("turtle");
}

/*******************************************************************************

    Simple logging layout that simply prints message omitting all extra info

*******************************************************************************/

private class SimpleLayout : Appender.Layout
{
    import ocean.text.convert.Formatter;

    private static int indent_count;

    invariant ( )
    {
        assert (SimpleLayout.indent_count >= 0);
    }

    override void format (LogEvent event, scope void delegate(cstring) dg)
    {
        static mstring buffer;
        sformat(buffer, "[{0,-10}] ", event.name);

        dg (buffer[]);
        for (int i = 0; i < SimpleLayout.indent_count; i++)
            dg ("    ");
        dg (event.toString());

        buffer.length = 0;
        enableStomping(buffer);
    }
}
