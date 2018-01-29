## Removal of deprecated functionality

* `turtle.application.model.TestedApplicationBase`

  `TestedApplicationBase.start_wait_delay` was originally deprecated in favor of
  `TestedApplicationDaemon.delay` and now removed completely.

* `turtle.runner.Logging`

  Doesn't call `setupLogging` in module constructor when compiled with
  `-version=UnitTest`. It is now only called when starting turtle runner.

* `turtle.runner.Runner`

  Third constructor argument (explicit sandbox folder name) is not supported
  anymore after original deprecation in v8.3.0
