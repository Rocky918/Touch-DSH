# Contributing

Thanks for helping improve Touch DSH.

1. Create a focused branch from `main`.
2. Keep shared behavior in `TouchDSHCore` or `TouchDSHShared`; edition-specific UI belongs in its edition target.
3. Do not add API keys, credentials, personal paths, complete logs, or generated build products.
4. Run `swift test` before submitting a pull request.
5. Describe the Mac model, architecture, macOS version, and DSH version used for manual testing.

Changes to the private Touch Bar bridge require testing on a physical Touch Bar Mac. Apple-silicon compilation on an Intel host is not a substitute for runtime testing.
