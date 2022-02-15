# 4. Use SQLite as a cache

Date: 2022-01-17

## Status

Accepted

## Context

This is a legacy decision, so I'm guessing a little bit as to the context. But I'm assuming that the performance of the GoSSB core was/is not good enough to drive a responsive UI.

## Decision

All SSB posts will be inserted into the GoSSB database first, then into a SQLite database later. The Planetary application code should only read from the SQLite database, and never read from the GoSSB database directly.

## Consequences

- In general write operations are made more expensive but read operations should be less expensive.
- We are trading disk space for database read spead - the app will be storing all post data twice.
- This allows Planetary application developers to build UI on a a familiar relational database.
