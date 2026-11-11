SATAN's runner (`~/dev/satan/dev/satan-test.el:117`) skips any test file whose
feature is already provided. If a runner is itself named `<pkg>-test`, the
client suite `<pkg>-test.el` provides the same feature, so it is skipped
without error and its tests never run.

**How to apply:** name a package's runner `<pkg>-test-runner` (as
`~/dev/umbriel.el/dev/umbriel-test-runner.el` does), and make the runner fail
when zero tests are loaded, so a skipped suite shows up as a failure.
