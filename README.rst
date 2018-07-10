Versioning
==========

Turtle's versioning follows `Neptune
<https://github.com/sociomantic-tsunami/neptune/blob/master/doc/library-user.rst>`_.

This means that the major version is increased for breaking changes, the minor
version is increased for feature releases, and the patch version is increased
for bug fixes that don't cause breaking changes.

Support Guarantees
------------------

* Major branch development period: 3 months
* Maintained minor versions: 1 most recent

Maintained Major Branches
-------------------------

====== ==================== ===============
Major  Initial release date Supported until
====== ==================== ===============
v9.x.x v9.0.0_: 29/01/2018  TBD
====== ==================== ===============

.. _v9.0.0: https://github.com/sociomantic-tsunami/turtle/releases/tag/v9.0.0

Description
===========

``turtle`` is a utility library intended to help with the creation of
application level black box tests. It consists of several major feature blocks:

- Spawning a tested application as a separate external process
- Automated facility for finding and running a test case
- Creation of a temporary sandbox for tested application

If needed these features can be used independently, but the recommended approach
is to base your test suite on ``turtle.runner.Runner`` which combines all the
features and avoids annoying boilerplate code.

Refer to example projects for a documented example on how to define a test suite
based on ``turtle.runner.Runner``.

.. contents::

Using turtle
============

Imagine you have a project called ``water`` and you want to add some higher
level tests based on turtle to it. This is suggested order of actions:

Creating the test runner
------------------------

The recommended practice is to have a main test runner with the same name as the
tested application. Thus, for this example of the ``water`` app, the matching
runner will be placed in ``test/water/main.d``. Makd will automatically compile
it and put the resulting binary in ``build/last/tmp/test-water``.

Create a test runner class which inherits from
``turtle.runner.Runner.TurtleRunner``, specifying the tested application kind
as a template argument:

.. code:: D

    class WaterTestRunner : TurtleRunner!(TestedAppKind.Daemon)
    {
        ...
    }

There are two mains supported kinds of tested applications - ``Daemon``
and ``CLI``. The former is for a persistent application which keeps running
in the background all the time while different test cases are executed and
only exits when all tests are finished. The latter is for a short-lived CLI
application which gets executed each time a test case is run, and after it
has terminated, the console output is verified.

To configure your test runner, you may need to override several ``TurtleRunner``
methods. ``configureTestedApplication``, ``prepare`` and ``reset`` are the
ones that are almost always needed.

Defining test cases
-------------------

``TurtleRunner`` will automatically find all classes derived from ``TestCase``
which are defined in the compiled modules and create them using
``Object.create``. The example projects show some example test cases - you
have to override ``description()`` to define any metadata (i.e. a test name),
``run()`` to define actual testing sequence and optionally ``prepare()`` to
set up some data (commonly used if you have your own custom test case base
class).

Any unhandled exception within ``run()`` will be considered a test failure - it
is recommended to use the same ``ocean.core.Test`` function as you do with unit
tests.

Usually any test case looks like a sequence of these actions:

1. Prepare some data in the mock environment or filesystem.
2. Wait for the tested application to process it (or run the tested
   application if it is a CLI one),
3. Verify that the tested application has made expected changes in the
   mock environment or filesystem.

Other tests (which are generally uncommon) may verify the console output of the
tested application or any files that it may generate. It is advisable to try and
make test cases as small and straightforward as possible. Ideally, if a test
case fails, the reason for the failure should be apparent even for someone who
isn't very familiar with the application. When it comes to testing, clarity
regarding the verified scenario is even more important than DRY. Avoid
complicated class hierarchies and prefer writing the test code in a verbose and
"dumb" manner if that helps to make the intention clearer.

It is perfectly fine for a project to even have hundreds of classes derived from
``TestCase`` if needed.

Test case placement
~~~~~~~~~~~~~~~~~~~

It is important to make sure that all your modules which define test cases are
imported from a module which defines test runner. Suggested layout to make it
simple:

.. code::

    test/
        water/
            cases/
                basic.d
                complex.d
                regressions.d
                all.d
            main.d

Then make sure ``all.d`` imports all other modules:

.. code:: D

    module test.water.cases.all;
    // public import is not necessary, runtime reflection ignores
    // protection attributes
    import test.water.cases.basic;
    import test.water.cases.complex;
    import test.water.cases.regressions;

And import it from ``main.d`` / runner module:

.. code:: D

    module test.water.main;
    import turtle.runner.Runner;
    import test.water.cases.all;

    class MyTurtleTests : TurtleRunner!(TestedAppKind.Daemon)

This way you can add new test at any time without ever having to modify a
module with the test runner (and only having to modify ``all.d`` if you add a
new module in ``test.water.cases``).

Limiting the test lookup package
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you use custom abstract base classes derived from ``TestCase`` it is
important to ensure that they won't be used by ``TurtleRunner`` as an actual
test case (trying to create an instance of such a class via runtime reflection
will result in a mysterious crash).

When all test cases are put into a dedicated package as suggested above, it
is trivial to tell ``TurtleRunner`` to only search for test cases there:

.. code:: D

    class MyTurtleTests : TurtleRunner!(TestedAppKind.Daemon)
    {
        this ( )
        {
            // second argument is the package name to use
            super("appbinary", "test.water.cases");
        }

This allows for putting an abstract base class for custom test cases anywhere
other than in the ``test.water`` package.

Nested test cases
~~~~~~~~~~~~~~~~~

Sometimes it is very hard or even impossible to statically define a dedicated
class for each test. One common case is automated generation of every single
combination from a test matrix, for example, testing a bunch of scenarios with
different starting data.

Turtle supports a special kind of ``TestCase`` which is defined in the same
module (``turtle.TestCase``) and is called ``MultiTestCase``. It is identical to
the plain test case but has a default empty non-abstract implementation of
``run()`` and defines a new abstract method ``TestCase[] getNestedCases()``.

``TurtleRunner`` recognizes ``MultiTestCase`` as a special base class and will
recursively run all tests returned by ``getNestedCases()`` in the same way as it
processes all tests found by runtime reflection. This means that test cases
returned by ``getNestedCases()`` can in turn also be ``MultiTestCase``.

Note that it is recommended to only use this feature if you have to generate
tests in an automated manner and not to define manual nested hierarchies. This
makes adding new tests more error-prone (easy to add a new test and forget to
add it to the manually maintained list).
