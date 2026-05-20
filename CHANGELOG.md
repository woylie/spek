# Changelog

## Unreleased

## [0.2.0] - 2026-05-20

### Added

- `Spek.collect_results/1`
- `Spek.collect_results/2`
- `Spek.eval_collect/2`
- `Spek.eval_collect!/2`
- `Spek.eval_collect_all/2`
- `Spek.eval_collect_all!/2`
- `Spek.EvaluationError.put_results/1`

### Changed

- Add `results` field to `Spek.EvaluationError` struct.

## [0.1.2] - 2026-05-18

### Changed

- Improve documentation.

## [0.1.1] - 2026-05-17

### Fixed

- Allow calling `Spek.Macros.defcheck/2` without arguments.
- Type specification for the `fun` field of `t:Spek.Check.t()`.

## [0.1.0] - 2026-05-17

Initial release.
