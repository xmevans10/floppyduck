fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios setup_app

```sh
[bundle exec] fastlane ios setup_app
```

Create the App Store Connect app record if it does not already exist

### ios register_iaps

```sh
[bundle exec] fastlane ios register_iaps
```

Register StoreKit non-consumable IAPs from FloppyDuckProducts.storekit

### ios iap_plan

```sh
[bundle exec] fastlane ios iap_plan
```

Print the IAP records that would be registered from FloppyDuckProducts.storekit

### ios certs

```sh
[bundle exec] fastlane ios certs
```

Fetch App Store distribution signing assets with match

### ios set_app_store_id

```sh
[bundle exec] fastlane ios set_app_store_id
```

Replace GK.appStoreID with REAL_APP_STORE_ID or APP_STORE_ID

### ios build

```sh
[bundle exec] fastlane ios build
```

Build an App Store archive and IPA for TestFlight

### ios upload

```sh
[bundle exec] fastlane ios upload
```

Upload the generated IPA to TestFlight

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload App Store metadata and screenshots without submitting for review

### ios setup

```sh
[bundle exec] fastlane ios setup
```

Create/update app record and IAP records

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and upload to TestFlight

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
