# 6. adopt-swiftui-incrementally

Date: 2022-10-11

## Status

Accepted

## Context

Apple has made it clear that SwiftUI is the future of UI frameworks on Apple platforms. It significantly reduces the development time for new UI by making views a function of state. 

SwiftUI cannot do everything that UIKit can do yet, and it has some weak areas like its navigation system.

Planetary currently uses UIKit with AutoLayout constraints defined in code. This avoids some of the problems with storyboards and nib files, but it makes creating and debugging views very slow.

## Decision

We will write new views in SwiftUI, and slowly begin rewriting our existing views in SwiftUI. 

## Consequences

- Rewriting new views can take a long time and will slow down our rate of adding new features.
- Learning SwiftUI will take time for our employees and contributors.
- In the long run creating and changing UI should be faster and contain fewer bugs.
- In the long run we will have an easier time supporting a macOS client, localization, and accessiblity.
