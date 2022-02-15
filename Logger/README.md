# Logger

** This library is part of [`Planetary`](https://github.com/planetary-social/planetary-ios) app. It is not intended to be used standalone.**

----

The `Logger` component encapsulates the logging requirements of `Planetary`, it logs everything to the filesystem and displays them in the console as well. 

## Usage

Just import the module and start using the logging functions in `Log`. Just some examples:

```swift
import Logger

Log.optional(error)
Log.info("This is important, display it everytime")
Log.debug("Display this just when debugging")
Log.unexpected(.apiError)
Log.fatal(.missingValue)
Log.error("Something bad happened")
```


