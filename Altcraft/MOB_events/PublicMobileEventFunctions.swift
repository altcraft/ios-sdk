//
//  PublicMobileEventFunctions.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Public API for sending Altcraft mobile events to the server.
@objcMembers
public class PublicMobileEventFunctions: NSObject, @unchecked Sendable {
    
    public static let shared = PublicMobileEventFunctions()
    
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
    public func mobileEvent(
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
            errorEvent(#function, error: fieldsIsObjects)
            return
        }
        
        MobileEventQueues.entityQueue.submit {
            await MobileEvent.shared.sendMobileEvent(
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
        mobileEvent:
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
    public func mobileEvent(
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
        self.mobileEvent(
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
