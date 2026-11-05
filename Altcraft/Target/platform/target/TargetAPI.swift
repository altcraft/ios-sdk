//
//  TargetAPI.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Public API for sending Altcraft mobile (target) events to the server.
@objcMembers
@objc(PublicMobileEventFunctions)
public class TargetAPI: NSObject, @unchecked Sendable {

    public static let shared: TargetAPI = {
        Target.ensureRegistered()
        return TargetAPI()
    }()

    /// Sends a mobile event to the server.
    ///
    /// This function prepares and triggers the delivery of a mobile event composed of
    /// mandatory identifiers and optional metadata. It mirrors the Android public API
    /// for consistency across platforms.
    ///
    /// - Parameters:
    ///   - sid: The string ID of the pixel.
    ///   - altcraftClientID: Altcraft client identifier.
    ///   - eventName: Mobile event name.
    ///   - sendMessageId: Send Message ID (SMID).
    ///   - payload: Arbitrary event data as a map; will be serialized to JSON.
    ///   - matching: Optional key/value pair for matching; will be serialized to JSON.
    ///   - matchingType: Type of matching (e.g., `"push_sub"`, `"email"`, etc.).
    ///   - profileFields: Optional profile fields to include in the request.
    ///   - subscription: The subscription to be attached to the profile.
    ///   - utm: Optional UTM tag structure for campaign attribution.
    @nonobjc
    public func sendTarget(
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
        let utmTagsData = encodeUTM(utm)
        let payloadData = encodeAnyMap(payload)
        let matchingData = encodeAnyMap(matching)
        let profileFieldsData = encodeAnyMap(profileFields)
        let subscriptionData = encodeSubscription(subscription)
        if (payload ?? [:]).containsNonPrimitiveValues() {
            TargetLog.error(#function, error: CoreEvents.fieldsIsObjects)
            return
        }

        TargetEventQueues.entityQueue.submit {
            await TargetEventProcess.shared.sendTargetEvent(
                sid: sid,
                eventName: eventName,
                payloadData: payloadData,
                matchingData: matchingData,
                sendMessageId: sendMessageId,
                profileFieldsData: profileFieldsData,
                subscriptionData: subscriptionData,
                altcraftClientID: altcraftClientID,
                matchingType: matchingType,
                utmTagsData: utmTagsData
            )
        }
    }

    // MARK: - Objective-C bridge

    @available(swift, obsoleted: 1)
    @objc(
        sendTarget:
        altcraftClientID:
        eventName:
        sendMessageId:
        payload:
        matching:
        matchingType:
        profileFields:
        subscription:
        utmCampaign:
        utmContent:
        utmKeyword:
        utmMedium:
        utmSource:
        utmTemp:
    )
    /// Objective-C entry point for `sendTarget(...)` accepting `NSDictionary`
    /// payload, matching and profile fields plus `SubscriptionObjC`.
    public func sendTarget(
        _ sid: String,
        altcraftClientID: String,
        eventName: String,
        sendMessageId: String?,
        payload: NSDictionary? = nil,
        matching: NSDictionary? = nil,
        matchingType: String? = nil,
        profileFields: NSDictionary? = nil,
        subscription: SubscriptionObjC? = nil,
        utmCampaign: String? = nil,
        utmContent: String? = nil,
        utmKeyword: String? = nil,
        utmMedium: String? = nil,
        utmSource: String? = nil,
        utmTemp: String? = nil
    ) {
        self.sendTarget(
            sid: sid,
            altcraftClientID: altcraftClientID,
            eventName: eventName,
            sendMessageId: sendMessageId,
            payload: payload as? [String: Any?],
            matching: matching as? [String: Any?],
            matchingType: matchingType,
            profileFields: profileFields as? [String: Any?],
            subscription: subscription?.toSwift(),
            utm: UTM(
                campaign: utmCampaign,
                content: utmContent,
                keyword: utmKeyword,
                medium: utmMedium,
                source: utmSource,
                temp: utmTemp
            )
        )
    }
}
