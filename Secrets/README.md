# Secrets

** This package is part of [`Planetary`](https://github.com/planetary-social/planetary-ios). It is not intended to be used standalone.**

----

`Secrets` is a simple key-value storage utility to retrieve secrets in a secure way:

- Store third-party service tokens and API keys
- Retrieve them in runtime

## Usage

Import the `Secrets` module and use the `get` function declared in the `Keys` class. For example:

```swift
import Secrets

let value = Secrets.shared.get(.posthog)
```

### The Secrets.plist file

The target must have a `Secrets.plist` file in the bundle resources. It can be empty, or can contain any of the keys listed in the `Key` enum. For example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>posthog</key>
        <string>The posthog key here</string>
        <key>bugsnag</key>
        <string>The busnag key here</string>
</dict>
</plist>
```
