# README Altcraft iOS SDK

![Altcraft SDK Logo](https://guides.altcraft.com/img/logo.svg)

[![Swift](https://img.shields.io/badge/Swift-5.10%2B-blue?style=flat-square)](https://swift.org/)
[![Platforms](https://img.shields.io/badge/Platforms-iOS-green?style=flat-square)](https://developer.apple.com/ios/)
[![Push Providers](https://img.shields.io/badge/Push-APNs_Firebase_Huawei-orange?style=flat-square)](#)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)


Altcraft iOS SDK is a library for managing push notifications, user profiles, and interacting with the **Altcraft Marketing** platform.
The SDK automates push notification delivery, event submission, request retries, and supports flexible workflows with JWT or role-based tokens.

---

## Features

* [x] Works with anonymous and registered users; supports multiple profiles on one device (JWT).
* [x] Push subscription management: `pushSubscribe()`, `pushSuspend()`, `pushUnSubscribe()`.
* [x] Automatic display of push notifications configured in the platform.
* [x] Automatic push token update when it changes.
* [x] Automatic transmission of notification delivery and open events.
* [x] Mobile events registration.
* [x] Automatic retry of failed requests.
* [x] Support for push providers: APNS, Firebase, Huawei.
* [x] Secure requests using JWT and flexible identifier matching.
* [x] Support for `rToken` for simple subscription scenarios.
* [x] SDK data cleanup (`clear()`) and background task termination.

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

* IOS 13.0.
* Push providers integrated SDK (APNs, Firebase, Huawei).

---

## Documentations

Detailed information on SDK setup, functionality, and usage is available on the Altcraft documentation portal. You can navigate to the required section using the links below:

Detailed information on SDK setup, functionality, and usage is available on the Altcraft documentation portal. You can navigate to the required section using the links below:

- [**Quick Start**](https://guides.altcraft.com/en/developer-guide/sdk/v2/ios/quick-start)
- [**SDK Functionality**](https://guides.altcraft.com/en/developer-guide/sdk/v2/ios/functionality)
- [**SDK Configuration**](https://guides.altcraft.com/en/developer-guide/sdk/v2/ios/setup)
- [**Classes and Structures**](https://guides.altcraft.com/en/developer-guide/sdk/v2/ios/functions-and-classes)
- **Provider Setup**

  * [APNs](https://guides.altcraft.com/en/developer-guide/sdk/v2/ios/providers/apns/)
  * [FCM](https://guides.altcraft.com/en/developer-guide/sdk/v2/ios/providers/fcm/)
  * [HMS](https://guides.altcraft.com/en/developer-guide/sdk/v2/ios/providers/hms/)

---

## Licenses

### EULA

END USER LICENSE AGREEMENT

Copyright © 2024 Altcraft LLC. All rights reserved.

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

Apache License 2.0

* [Swift](https://swift.org)
* [SwiftUI](https://developer.apple.com/documentation/swiftui)

Apple Developer License Agreement

* [Foundation](https://developer.apple.com/documentation/foundation)
* [MobileCoreServices](https://developer.apple.com/documentation/mobilecoreservices)
* [CryptoKit](https://developer.apple.com/documentation/cryptokit)
* [UIKit](https://developer.apple.com/documentation/uikit)
* [BackgroundTasks](https://developer.apple.com/documentation/backgroundtasks)
* [CoreData](https://developer.apple.com/documentation/coredata)
* [AdSupport](https://developer.apple.com/documentation/adsupport)
* [Network](https://developer.apple.com/documentation/network)
* [UserNotifications](https://developer.apple.com/documentation/usernotifications)

