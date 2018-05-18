# instrumented_tests plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-instrumented_tests)

## Getting Started

This project is a [fastlane](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-instrumented_tests`, add it to your project by running:

```bash
fastlane add_plugin instrumented_tests
```

## About instrumented_tests

Run instrumented tests for android. 

This basically creates and boots an emulator before running an gradle commands so that you can run instrumented tests against that emulator. After the gradle command is executed, the avd gets shut down and deleted. This is really helpful on CI services, keeping them clean and always having a fresh avd for testing.

## Example

Check out the [example `Fastfile`](fastlane/Fastfile) to see how to use this plugin. Try it by cloning the repo, running `fastlane install_plugins` and `bundle exec fastlane test`. 

Creates and boots avd device before running gradle command.

```ruby
instrumented_tests(
  avd_name: "Nexus_5_API_25_Test",
  avd_package: "'system-images;android-19;google_apis;x86'",
  avd_abi: "google_apis/x86",
)
```

## Run tests for this plugin

To run both the tests, and code style validation, run

````
rake
```

To automatically fix many of the styling issues, use 
```
rubocop -a
```

## Other notes

Found while searching for this type of plugin, https://github.com/fastlane/fastlane/pull/4315 https://github.com/joshrlesch/fastlane/tree/fastlane-instrument-tests
Changed to plugin infrastructure.

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://github.com/fastlane/fastlane/blob/master/fastlane/docs/PluginsTroubleshooting.md) doc in the main `fastlane` repo.

## Using `fastlane` Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Plugins.md).

## About `fastlane`

`fastlane` is the easiest way to automate building and releasing your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
