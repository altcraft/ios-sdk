//
//  RetryTrackable+InApp.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

extension InAppSubscribeEntity: RetryTrackable {}
extension InAppEventEntity: RetryTrackable {}
