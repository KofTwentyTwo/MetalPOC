# Contributing to MetalPOC

This is a proof-of-concept project. Contributions are welcome but kept lightweight.

## Reporting bugs

Open an [issue](../../issues) with:
- macOS version + hardware (Apple Silicon vs. Intel)
- Xcode + xcodegen version
- Steps to reproduce
- Expected vs. actual behavior
- Screenshots / screen recording if visual

## Suggesting features

Open an issue describing the use case and the visual or behavioral change. For tunable knobs (colors, sizes, intervals), there's likely already a parameter in `Sources/Theme.swift` — try editing that first.

## Pull requests

1. Fork the repo and create a branch from `main`.
2. Keep changes scoped — one logical change per PR.
3. If touching shader code, run with Metal validation enabled and confirm no GPU API errors:
   ```bash
   MTL_DEBUG_LAYER=1 MTL_SHADER_VALIDATION=1 build/Debug/MetalPOC.app/Contents/MacOS/MetalPOC
   ```
4. Match the existing code style. Centralize new tunables into `Sources/Theme.swift` rather than hard-coding values inside widgets.
5. Open a PR with a brief description of what changed and why.

## Code of conduct

Be respectful. This is a tiny POC repo, not a community — but kindness still applies.
