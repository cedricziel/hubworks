# Changelog

## [0.1.1](https://github.com/cedricziel/hubworks/compare/HubWorks-v0.1.0...HubWorks-v0.1.1) (2026-02-01)


### Features

* Add crypto export compliance, release automation, and build versioning ([#4](https://github.com/cedricziel/hubworks/issues/4)) ([4d6d192](https://github.com/cedricziel/hubworks/commit/4d6d192cc2835aaf4c1d583344d7179a7053e26b))
* Implement upsert logic for notifications ([4a66098](https://github.com/cedricziel/hubworks/commit/4a66098130f3638cace0c6f9dd44bfe0bd185d9c))
* Initial commit - HubWorks GitHub notification app ([b557177](https://github.com/cedricziel/hubworks/commit/b55717797b204fd9aec5701910d31f8e331e3ef3))
* **macos:** Add menu bar notification filtering and limit controls ([#3](https://github.com/cedricziel/hubworks/issues/3)) ([facb3db](https://github.com/cedricziel/hubworks/commit/facb3db272aaa0785fc52a2790b262db8e368620))
* **macOS:** Add NavigationSplitView sidebar layout ([e4363f1](https://github.com/cedricziel/hubworks/commit/e4363f1d7e1bd6771de41b050dce559186796869))
* **settings:** Renovate macOS Settings view with HIG-compliant design ([953f920](https://github.com/cedricziel/hubworks/commit/953f9207c2b406c201d7d50fe81e089669b02013))


### Bug Fixes

* **ci:** Add test configuration to macOS scheme ([d758183](https://github.com/cedricziel/hubworks/commit/d75818367ae66faadf9794fef0729d0e67bd9cdb))
* **ci:** Copy Secrets.xcconfig template for CI builds ([65c3fa7](https://github.com/cedricziel/hubworks/commit/65c3fa71e45536e573b962f4d1431e1fc9c31da2))
* **inbox:** Add visual feedback for sidebar repository selection ([#2](https://github.com/cedricziel/hubworks/issues/2)) ([23f713c](https://github.com/cedricziel/hubworks/commit/23f713cd51ba4626e50ff28f0536773f54f67dc5))
* Increase pagination limit to 2000 notifications (20 pages) ([5c48b57](https://github.com/cedricziel/hubworks/commit/5c48b576b2d7dd2bd83d70c7e59e4937ae7bf38c))
* Increase safety limit to 5000 notifications, paginate until done ([90f1959](https://github.com/cedricziel/hubworks/commit/90f1959f6ac29c785ecc01fb859c7b037eebe2a8))
* Remove pagination limit, fix duplicate notification crash ([078359e](https://github.com/cedricziel/hubworks/commit/078359e4afb01676408e8877c3bf10748a3c9587))
* Resolve SwiftLint errors for CI compliance ([ac28f91](https://github.com/cedricziel/hubworks/commit/ac28f91c3fadcc55934c947f449b343eaa257031))
* Resolve SwiftLint violations for CI ([3ae0a3b](https://github.com/cedricziel/hubworks/commit/3ae0a3b2ea4f39d08b328a905dfda5c29afdbcc3))


### Code Refactoring

* Migrate to SwiftData reactive queries for notifications ([7214b37](https://github.com/cedricziel/hubworks/commit/7214b3757c43d1adc91f47b394285190fd3a72a3))
