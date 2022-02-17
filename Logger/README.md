# Logger

** This package is part of [`Planetary`](https://github.com/planetary-social/planetary-ios). It is not intended to be used standalone.**

----

`Logger` is a simple logging utility to output messages with the following features:

- Print messages to different levels such as info and error
- Auto-rolling of log files

## Usage

Import the `Logger` module and use any functions declared in the `Log` class. Just some examples:

```swift
import Logger

Log.optional(error)
Log.info("This is important, display it everytime")
Log.debug("Display this just when debugging")
Log.unexpected(.apiError)
Log.fatal(.missingValue)
Log.error("Something bad happened")
```
