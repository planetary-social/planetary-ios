# 3. Manually manage Bugsnag Upload dSYMs Script

Date: 2022-01-10

## Status

Accepted

## Context

The Bugsnag Upload dSYMS script is failing on CI and creates an extra step for contributors setting up a development environment. The cocoapods-bugsnag plugin doesn't seem to support these use cases. We have opened an issue with them [here](https://github.com/bugsnag/cocoapods-bugsnag/issues/23).

## Decision

We will manually manage the "Upload Bugsnag dSYM" build phase script rather than letting it be managed by the cocoapods-bugsnag plugin.

## Consequences

If bugsnag changes their script we will not get updates automatically. We will have to remember to check for updates manually whenever update the Bugsnag pod.
