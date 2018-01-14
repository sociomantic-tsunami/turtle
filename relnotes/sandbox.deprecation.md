## Manual specification of sandbox name is deprecated

Relying on developer to manually provide unique sandbox names when constructing
turtle runner has proven to be overly error-prone and caused hard to debug
issues when multiple test suite competed for the same sandbox.

To ensure this doesn't happen again `TurtleRunner` constructor with 3 arguments
is deprecated and sandbox name will now be automatically generated using
`mkdtemp`. Previously it would always use tested binary name if sandbox name was
not supplied explicitly.
