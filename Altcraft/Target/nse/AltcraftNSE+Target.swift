//
//  AltcraftNSE+Target.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Target / mobile-event NSE APIs.
///
/// Available when the `AltcraftTarget` module (Pod / SPM product) is present.
public extension AltcraftNSE {

    /// Sends a mobile (target) event.
    ///
    /// This is the NSE-friendly version of
    /// ``TargetAPI/sendTarget(sid:altcraftClientID:eventName:sendMessageId:payload:matching:matchingType:profileFields:subscription:utm:)``.
    /// It forwards to ``TargetAPI/shared``.
    ///
    /// - Parameters:
    ///   - sid: Sender identification.
    ///   - altcraftClientID: Optional Altcraft client id (defaults to `""`).
    ///   - eventName: Name of the event being reported.
    ///   - sendMessageId: Optional send-message id.
    ///   - payload: Optional event payload.
    ///   - matching: Optional matching criteria.
    ///   - matchingType: Optional matching type (e.g. `"push_sub"`, `"email"`).
    ///   - profileFields: Optional profile fields to include in the request.
    ///   - subscription: Optional subscription to attach to the profile.
    ///   - utm: Optional UTM tag structure for campaign attribution.
    static func sendTarget(
        sid: String,
        altcraftClientID: String = "",
        eventName: String,
        sendMessageId: String? = nil,
        payload: [String: Any?]? = nil,
        matching: [String: Any?]? = nil,
        matchingType: String? = nil,
        profileFields: [String: Any?]? = nil,
        subscription: (any Subscription)? = nil,
        utm: UTM? = nil
    ) {
        TargetAPI.shared.sendTarget(
            sid: sid,
            altcraftClientID: altcraftClientID,
            eventName: eventName,
            sendMessageId: sendMessageId,
            payload: payload,
            matching: matching,
            matchingType: matchingType,
            profileFields: profileFields,
            subscription: subscription,
            utm: utm
        )
    }
}
