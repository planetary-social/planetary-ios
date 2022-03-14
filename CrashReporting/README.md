# CrashReporting

** This package is part of [`Planetary`](https://github.com/planetary-social/planetary-ios). It is not intended to be used standalone.**

----

`CrashReporting` is a simple crash reporting utility to handled or unhandled errors:

- Track events in [Bugsnag](https://bugsnag.com)
- Let user opt-in or opt-out from using CrashReporting

## Usage

Import the `CrashReporting` module and use any public function declared in the `CrashReporting` class. For example:

```swift
import CrashReporting

CrashReporting.shared.crash()
```

### The Secrets.plist file

In order to enable CrashReporting the target must have a `Secrets.plist` file in the bundle resources with a key 
named `bugsnag` (the value should be the Notifier API key). For example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>bugsnag</key>
        <string>The bugsnag key here</string>
</dict>
</plist>
```

CrashReporting is automatically disabled if the key doesn't exist or is empty.
