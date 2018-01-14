## Improve log output upon unexpected termination

Now instead of just printing `Early termination from 'app', aborting`, turtle
will also log last stderr/stdout lines from the tested application, even if
normally logging if tested application output is disabled.

Turtle will also mention spawned process command-line arguments if any.
