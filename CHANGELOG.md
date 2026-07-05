# Changelog

## [1.1.0] - 2026-07-05

### Added

- Add a ggHash method and a hashJson method to allow to create 128 bit hashes on arbitrary strings and hash JSON files
- Add example code
- Add .gitattributes file
- Add benchmarks and golden checks (`benchmark/`)

### Changed

- Improve performance of `fnv1` and `hashJson` significantly while keeping
all hashes bit-identical: `fnv1` no longer copies 8-byte-aligned typed
data whose length is not a multiple of 8 and uses specialized loops for
lists; `hashJson` hashes in a single pass, serializes JSON directly to
reusable UTF-8 buffers and uses a built-in, allocation-free SHA-256
- Move the `crypto` package from `dependencies` to `dev_dependencies`;
it is only used in tests now to verify the built-in SHA-256
- Optimize performance using claude

## [1.0.4] - 2024-04-13

### Removed

- dependency to gg\_install\_gg, remove ./check script
- dependency pana

## [1.0.3] - 2024-04-09

### Removed

- 'Pipline: Disable cache'

## [1.0.2] - 2024-04-09

### Changed

- Kidney: Auto check all repos
- Rework changelog
- 'Github Actions Pipeline'
- 'Github Actions Pipeline: Add SDK file containing flutter into .github/workflows to make github installing flutter and not dart SDK'

## [1.0.1] - 2024-04-05

### Changed

- Updated to latest dependencies
- Pipeline: Took over from gg

## 1.0.0 - 2024-02-02

### Added

- Initial version.

[1.1.0]: https://github.com/inlavigo/gg_hash/compare/1.0.4...1.1.0
[1.0.4]: https://github.com/inlavigo/gg_hash/compare/1.0.3...1.0.4
[1.0.3]: https://github.com/inlavigo/gg_hash/compare/1.0.2...1.0.3
[1.0.2]: https://github.com/inlavigo/gg_hash/compare/1.0.1...1.0.2
[1.0.1]: https://github.com/inlavigo/gg_hash/compare/1.0.0...1.0.1
