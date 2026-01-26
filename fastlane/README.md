fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios tests

```sh
[bundle exec] fastlane ios tests
```

Pre-flight Check: Run all 206+ Unit Tests

### ios alpha

```sh
[bundle exec] fastlane ios alpha
```

Internal Alpha: Distribute via Firebase App Distribution

### ios beta

```sh
[bundle exec] fastlane ios beta
```

External Beta: Submit to TestFlight

### ios get_testflight_build_number

```sh
[bundle exec] fastlane ios get_testflight_build_number
```

Get latest TestFlight build number

### ios test_report

```sh
[bundle exec] fastlane ios test_report
```

Run tests and generate report

### ios sync_certs

```sh
[bundle exec] fastlane ios sync_certs
```

Sync certificates and profiles (manual run if needed)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
