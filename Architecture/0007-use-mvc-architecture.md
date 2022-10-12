# 7. use-mvc-architecture

Date: 2022-10-11

## Status

Accepted

Amended by [8. use-uikit-navigation](0008-use-uikit-navigation.md)

## Context

We are starting to write new views in SwiftUI, which warrants a re-thinking of our app architecture. Planetary in some cases suffers from the Massive View Controller problem where View Controllers assume too much responsibility and hold too much state.

With the advent of SwiftUI some teams are leaning towards simpler archictures - even as simple as binding SwiftUI views directly to the model layer. Others rely on more complex schemes like Redux or VIPER. 

We are a small team and as a startup we want to stay nimble. Code clarity and testability are always important but we want to stay away from boilerplate code and prefer composition over inheritance. 

The following blog posts have informed our decision
- [SwiftUI: Choosing an Application Architecture - Client Resources, Inc.](https://www.clientresourcesinc.com/2022/04/29/swiftui-choosing-an-application-architecture/)
- [The Strategic SwiftUI Data Flow Guide (+ Infographic)](https://matteomanferdini.com/swiftui-data-flow/)

## Decision

We will use a Model-View-Controller architecure for our app. We define these components as follows:
- Model: A robust expression of our domain objects and logic, using the full extent of Swift's type system. The model layer contains our sources of truth.
- View: The way we represent information to the user.
- Controller: A two-way binding layer between the Model and View layers. Loads the specific models needed for a particular view manipulates them in response to user actions in the view.

Using this architecture we endeavor to:
- Maintain a single source of truth for a given piece of data. 
- Be mindful of state and push as low in the app hierarchy as possible. 
- Keep view creation lightweight. Composing views should feel natural and easy and in general only require a single parameter.

The model layer and controller layers should be extensively covered by unit tests. The SwiftUI preview canvas should be used to test views.

SwiftUI views will, in general, contain an @ObservableObject reference to a single controller. The controller will maintain a reference to model repositories or the Bot (see ADR #8). 

## Consequences

- Our app architecture should be easy for new contributors to understand.
- The simplicity of the architecture means there will be variations in its implementation througout the app.
- New components should be easy to add.
- Some components will have more than one responsibility. This makes small and components more readable but hurts the readability of large components.
