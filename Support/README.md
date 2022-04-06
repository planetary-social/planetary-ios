# Support

** This package is part of [`Planetary`](https://github.com/planetary-social/planetary-ios). It is not intended to be used standalone.**

----

`Support` is a simple utility to create screens in which the user can:

- Submit a bug to [Zendesk](https://posthog.com)
- Report an abusive profile
- Report an offensive post
- Read documentation about how Planetary and Scuttlebutt works

## Usage

Import the `Support` module and use any public function declared in the `Support` class. For example:

```swift
import Support

let viewController = Support.shared.mainViewController()
```

The client is the one responsible of displaying the resulting view controller in the screen.

### Submitting a bug 

Bugs are reported anonymously. In order to create a view controller that lets the user submit a new bug just:

 ```swift
import Support

let viewController = Support.shared.newTicketViewController(botLog: nil)
```

The `botLog` is created automatically by Planetary's `Support+GoBot.swift` extension.

### Reporting an abusive profile 

A profile can be reported using the `SupportProfile` struct, it contains the profile identity and name (optional):

 ```swift
import Support

let profile = SupportProfile(identifier: "profile-ref", name: "Lucas")
let viewController = Support.shared.newTicketViewController(reporter: "my-ref", profile: profile, botLog: nil)
```

The `botLog` is created automatically by Planetary's `Support+GoBot.swift` extension.

### Reporting an offensive content 

A content can be reported using the `SupportContent` struct, it contains the content key, the profile of the creator of that content, a reason (listed in `SupportReason`) and an instance of a UIView that Support uses for taking a screenshot of the content, that UIView must be displaying the offensive post:

 ```swift
import Support

let profile = SupportProfile(identifier: "profile-ref", name: "Lucas")
let content = SupportContent(
    identifier: "content-ref",
    profile: profile,
    reason: .copyright,
    view: aViewDisplayingTheOffensivePost
)
let viewController = Support.shared.newTicketViewController(reporter: "my-ref", content: content, botLog: nil)
```

The `botLog` is created automatically by Planetary's `Support+GoBot.swift` extension.

### Reading documentation 

The available documentation articles are listed in `SupportArticle`, in order to create a view controller that displays one of these articles just:

 ```swift
import Support

let article = SupportArticle.frequentlyAskedQuestions
let viewController = Support.shared.articleViewController(article)
```

### The Secrets.plist file

In order to enable Support the target must have a `Secrets.plist` file in the bundle resources with two keys 
named `zendeskAppID` and `zendeskClientID`. For example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>zendeskAppID</key>
        <string>The zendeskAppID key here</string>
        <key>zendeskClientID</key>
        <string>The zendeskClientID key here</string>
</dict>
</plist>
```

Support is automatically disabled if the keys don't exist.
