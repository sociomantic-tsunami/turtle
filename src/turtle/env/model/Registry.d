/*******************************************************************************

    Provides centralized registry where turtle env additions from other
    libraries can register themselves for the purpose of being notified about
    test suite shutdown.

    Copyright: Copyright (c) 2017 sociomantic labs GmbH. All rights reserved.

    License: Boost Software License Version 1.0. See LICENSE for details.

*******************************************************************************/

module turtle.env.model.Registry;

import ocean.core.array.Search;

/// ditto
public class TurtleEnvRegistry
{
    /***************************************************************************

        Array of environment additions previously registered

    ***************************************************************************/

    private ITurtleEnv[] known;

    /***************************************************************************

        Registers turtle environment addition hidden behind `ITurtleEnv`
        interface. Each registered interface will get its `unregister` method
        called upon test suite shutdown.

    ***************************************************************************/

    public void register ( ITurtleEnv env )
    {
        if (find(this.known[], env) >= this.known.length)
            this.known ~= env;
    }

    /***************************************************************************

        Should not be called from user code. Only declared public because of
        lack of `package(mod)` in D1.

    ***************************************************************************/

    public /* package(turtle) */ void unregisterAll ( )
    {
        foreach (env; this.known)
            env.unregister();
        this.known = [ ];
    }
}

/*******************************************************************************

    Turtle environment addition must implement this interface to be able to
    get notified about test suite shutdown to adjust own state accordingly.

*******************************************************************************/

public interface ITurtleEnv
{
    public void unregister ( );
}

/*******************************************************************************

    Registry "singleton".

*******************************************************************************/

public TurtleEnvRegistry turtle_env_registry;

static this ( )
{
    turtle_env_registry = new TurtleEnvRegistry;
}
