//
//  RetryTrackable+Push.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

extension PushEventEntity: RetryTrackable {}
extension PushSubscribeEntity: RetryTrackable {}
