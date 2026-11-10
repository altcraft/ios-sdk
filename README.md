# Altcraft iOS SDK

![Altcraft SDK Logo](https://guides.altcraft.com/img/logo.svg)

[![Swift](https://img.shields.io/badge/Swift-5.10%2B-blue?style=flat-square)](https://swift.org/)
[![Platforms](https://img.shields.io/badge/Platforms-iOS-green?style=flat-square)](https://developer.apple.com/ios/)
[![Push Providers](https://img.shields.io/badge/Push-APNs_Firebase_Huawei-green?style=flat-square)](#)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)

Altcraft iOS SDK is a library for interacting with the **Altcraft Marketing Platform**. It uses a modular architecture in which each component provides a specific set of capabilities.

---

## SDK Modules

### Core

The core is the foundation of the SDK: it connects your application to the Altcraft platform and makes the optional modules available.

* [x] SDK initialization and configuration.
* [x] Authentication with JWT or a role token (*rToken*).
* [x] Works with anonymous and registered users; supports multiple profiles on one device (JWT).
* [x] Transmission of requests to the platform with automatic retry of failed requests.
* [x] SDK event stream for monitoring SDK behavior in the app.
* [x] SDK data cleanup and background tasks termination.

### Push

The push module is responsible for push notifications.

* [x] Push subscription management: subscribe, suspend, unsubscribe.
* [x] Automatic display of push notifications configured in the platform.
* [x] Push token management: automatic update when the token changes, manual token operations.
* [x] Automatic transmission of notification delivery and open events.
* [x] Support for push providers: APNs, Firebase, Huawei.
* [x] Custom push notification handling and access to all message data fields.
* [x] Rich push notification processing via a Notification Service Extension (media, buttons).

### Target

The target module is responsible for mobile events: it sends target events to the platform to record goal achievements.

* [x] Sending target events (goal conversions) from the app.
* [x] Attaching event payloads, matching parameters, profile fields, and channel subscriptions to a target event.
* [x] Attaching UTM tags to target events for attribution.

### Profile

The profile module is responsible for user profile fields.

* [x] Updating profile fields from the app.

### In-App

The in-app module is responsible for in-app campaigns.

* [x] Automatic display of in-app campaigns configured in the platform.
* [x] In-app subscription management: subscribe, unsubscribe, status retrieval.
* [x] Placement requests, current screen matching, and custom triggers.
* [x] JSON in-app campaign emission to an external subscriber.

---

## Dependencies

Altcraft iOS SDK modules are distributed via Swift Package Manager. Add the modules used by your application. The Core module is included automatically as a dependency of other SDK modules and does not need to be added separately.

**Swift Package Manager:**

```swift
dependencies: [
    .package(url: "https://github.com/altcraft/ios-sdk", from: "2.0.0")
]
```

Add the products used by your application to the target dependencies:

```swift
.product(name: "AltcraftPush", package: "ios-sdk"),
.product(name: "AltcraftInApp", package: "ios-sdk"),
.product(name: "AltcraftTarget", package: "ios-sdk"),
.product(name: "AltcraftProfile", package: "ios-sdk"),
```

If you only need Core, add the `AltcraftCore` product directly.

---

## Authorization Types

### JWT-Authorization (recommended approach)

JWT is added to the header of every request. The SDK requests the current token from the app via the `JWTInterface`.

**Advantages:**

* Enhanced security of API requests.
* Profile lookup by any identifier (email, phone, custom ID).
* Support for multiple users on a single device.
* Profile persists after app reinstallation.
* Unified user identity across devices.

### Authorization with a role token (*rToken*)

The role token is specified in the SDK configuration.
Profile lookup is limited to the push token identifier.

**Limitations:**

* The link to a profile may be lost if the push token changes and the change isn’t reflected on the platform.
* No multi-profile support.
* It’s not possible to register the same user on another device.

---

## Requirements

* iOS 13.0+.
* A configured push provider (APNs, Firebase, or Huawei) when using the Push module.
* Xcode 15.3+ (Swift tools 5.10).

---

## Documentation

Detailed information on SDK setup, functionality, and usage is available on the Altcraft documentation portal. You can navigate to the required section using the links below:

- [**Quick Start**](https://guides.altcraft.com/en/developer-guide/sdk/mobile/ios/quick-start)
- [**SDK Functionality**](https://guides.altcraft.com/en/developer-guide/sdk/mobile/ios/functionality)
- [**SDK Configuration**](https://guides.altcraft.com/en/developer-guide/sdk/mobile/ios/setup)
- [**Classes and Structures**](https://guides.altcraft.com/en/developer-guide/sdk/mobile/ios/api)

**Provider Setup**

- [APNs](https://guides.altcraft.com/en/developer-guide/sdk/mobile/ios/providers/apns/)
- [FCM](https://guides.altcraft.com/en/developer-guide/sdk/mobile/ios/providers/fcm/)
- [HMS](https://guides.altcraft.com/en/developer-guide/sdk/mobile/ios/providers/hms/)

---

## License

### EULA

END USER LICENSE AGREEMENT

Copyright © 2026 Altcraft LLC. All rights reserved.

1. LICENSE GRANT
   This agreement grants you certain rights to use the Altcraft Mobile SDK (hereinafter referred to as the “Software”).
   All rights not expressly granted by this agreement remain with the copyright holder.

2. USE
   You are permitted to use and distribute the Software for both commercial and non-commercial purposes.

3. MODIFICATION WITHOUT PUBLICATION
   You may modify the Software for your own internal purposes without any obligation to publish such modifications.

4. MODIFICATION WITH PUBLICATION
   Publication of modified Software requires prior written permission from the copyright holder.

5. DISCLAIMER OF WARRANTIES
   The Software is provided “as is,” without any warranties, express or implied, including but not limited to
   warranties of merchantability, fitness for a particular purpose, and non-infringement of third-party rights.

6. LIMITATION OF LIABILITY
   Under no circumstances shall the copyright holder be liable for any direct, indirect, incidental, special,
   punitive, or consequential damages (including but not limited to: procurement of substitute goods or services;
   loss of data, profits, or business interruption) arising in any way from the use of this Software,
   even if the copyright holder has been advised of the possibility of such damages.

7. DISTRIBUTION
   When distributing the Software, you must provide all recipients with a copy of this license agreement.

8. COPYRIGHT AND THIRD-PARTY COMPONENTS
   This Software may include components distributed under other licenses. The full list of such components
   and their respective licenses is provided below:

### Third-party libraries and licenses

**Apple frameworks**
Licensed under the Apple Developer License Agreement.
You may obtain a copy of the License at https://developer.apple.com/terms/

* [Foundation](https://developer.apple.com/documentation/foundation)
* [MobileCoreServices](https://developer.apple.com/documentation/mobilecoreservices)
* [CryptoKit](https://developer.apple.com/documentation/cryptokit)
* [UIKit](https://developer.apple.com/documentation/uikit)
* [BackgroundTasks](https://developer.apple.com/documentation/backgroundtasks)
* [CoreData](https://developer.apple.com/documentation/coredata)
* [AdSupport](https://developer.apple.com/documentation/adsupport)
* [Network](https://developer.apple.com/documentation/network)
* [UserNotifications](https://developer.apple.com/documentation/usernotifications)

**Apache License 2.0**
Licensed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

* [Swift](https://swift.org)
* [SwiftUI](https://developer.apple.com/documentation/swiftui)
