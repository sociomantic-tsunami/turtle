/*******************************************************************************

    Module providing struct aggregator of tested application
    various stat counters.

    Copyright:
        Copyright (c) 2017 dunnhumby Germany GmbH. All rights reserved

*******************************************************************************/

module turtle.application.Stats;

/// Peak values of various counters observed in the application
/// during testing.
struct PeakStats
{
    /// virtual memory, bytes
    ulong vsize;
}
