# Analytics

** This package is part of [`Planetary`](https://github.com/planetary-social/planetary-ios). It is not intended to be used standalone.**

----

`Analytics` is a simple analytics utility to track user-generated events (like a tap on a button):

- Track events in the [PostHog](https://posthog.com)
- Let user opt-in or opt-out from using Analytics

## Usage

Import the `Analytics` module and use any public function declared in the `Analytics` class. They are declared
in extensions like `Analytics+UI.swift` or `Analytics+Statistics.swift`. For example:

```swift
import Analytics

Analytics.shared.trackDidTapButton("my-button")
```

### Opt-in

It is important to let the user decide if the app can send analytics events to the server or not. The `Analytics`
class provides the `optIn()` and the `optOut()` functions that enable or disable the functionality accordingly.

### The Secrets.plist file

In order to enable Analytics the target must have a `Secrets.plist` file in the bundle resources with a key 
named `posthog` (the value should be the Project API key). For example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>posthog</key>
        <string>The posthog key here</string>
</dict>
</plist>
```

Analytics is automatically disabled if the key doesn't exist or is empty.
