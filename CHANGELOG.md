# Changelog

All notable changes to `managoat_docs` are documented here. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[SemVer](https://semver.org/). Pre-1.0, a minor bump (`0.x` to `0.y`) may
include breaking changes and says so; patch releases are always safe to take.

Merging a version bump to `main` publishes it to hex; a PR that changes what
the package ships without a bump fails the release gate.

## [Unreleased]

## [0.1.1] - 2026-09-03

### Changed

- Raised the package's coverage gate from 90% to 96% after adding renderer
  coverage for trusted inline HTML and image URLs, plus failure coverage for
  missing pages and malformed search indexes.

## [0.1.0] - 2026-09-02

### Added

- Extracted from Fountain (BinaryBourbon/fountain#1367).
