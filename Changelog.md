### 9.0.0

- Support Swift Package Manager
- Remove support for cocoapods

### 8.0.0

### Changed

- Support SudoUser 16

### 7.0.0

### New

- Added a list of categorizations to reputation response. 

### 6.0.0

### New

- Update SudoUser annd API client depenednecies

### Fixed

- Fix a test case

### 5.0.0

### Breaking

This is an internal rework of the SDK and API service that supports it. 
- `SudoSiteReputationClient` and friends from previous version are and renamed with a `Legacy` prefix. This is to make way for the updated implementations to take over the `SudoSiteReputation` name.
- `DefaultSudoSiteReputationClient` has a new dependency on SudoUser SDK.
- `SiteReputation` return type has changed.

### New

- This is a internal rework and for the most part `SudoSiteReputationClient` should be considered new.
- `getReputation` has performance improvements and avoids duplicate requests.

### Fixed

- None.

### 4.1.1

- add a missing depenency in podspec.

# 3.0.0

### New

- Update to major new major versions of other platform SDK's.
- Migrate to swift structured concurrency.
- Bump minimum iOS version from 13 to 14 to support concurrency
- Add explicit dependency for AWSS3.

### Fixed

- None
