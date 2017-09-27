* `turtle.application.TestedDaemonApplication`
  `turtle.application.Stats`

  New module, `Stats` defines `PeakStats` structure which aggregates peak values
  of various metric observed for the tested application. Instance of such struct
  is returned by new application object method, `getPeakStats`, and is reset
  each time tested app is started anew.

  For now this struct contains only one field - virtual memory size.
