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
public class PublicMobileEventFunctions: NSObject {
    
    public static let shared = PublicMobileEventFunctions()
    
    //// Sends a mobile event to the server.
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
        let smid: String = sendMessageId ?? ""
        
        MobileEvent.shared.sendMobileEvent(
            sid: sid,
            eventName: eventName,
            sendMessageId: smid,
            payloadFields: payload,
            matching: matching,
            profileFields: profileFields,
            subscription: subscription,
            altcraftClientID: altcraftClientID,
            matchingType: matchingType,
            utmTags: utm
        )
    }
    
    // MARK: - Objective-C bridge (same selector name, hidden from Swift)
    //
    // Selector in ObjC:
    // mobileEvent:altcraftClientID:eventName:sendMessageId:payload:matching:matchingType:profileFields:subscription:utmCampaign:utmContent:utmKeyword:utmMedium:utmSource:utmTemp:
    //
    // Notes:
    // - `subscription`: ACTSubscriptionBase? (or any subclass: ACTEmailSubscription, ACTSmsSubscription, ACTPushSubscription, ACTCcDataSubscription)
    //   will be automatically converted to a Swift `Subscription` via `.toSwift()`.
    @available(swift, obsoleted: 1)
    @objc(mobileEvent:altcraftClientID:eventName:sendMessageId:payload:matching:matchingType:profileFields:subscription:utmCampaign:utmContent:utmKeyword:utmMedium:utmSource:utmTemp:)
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
        let smid: String = sendMessageId ?? ""
        
        // Compose UTM data
        let utm = UTM(
            campaign: utmCampaign,
            content: utmContent,
            keyword: utmKeyword,
            medium: utmMedium,
            source: utmSource,
            temp: utmTemp
        )
        
        // Convert Foundation types to Swift dictionaries
        let payloadFields     = payload as? [String: Any?]
        let matchingFields    = matching as? [String: Any?]
        let profileFieldsAny  = profileFields as? [String: Any?]
        
        // Convert ObjC subscription to Swift Subscription
        let swiftSubscription = subscription?.toSwift()
        
        MobileEvent.shared.sendMobileEvent(
            sid: sid,
            eventName: eventName,
            sendMessageId: smid,
            payloadFields: payloadFields,
            matching: matchingFields,
            profileFields: profileFieldsAny,
            subscription: swiftSubscription,
            altcraftClientID: altcraftClientID,
            matchingType: matchingType,
            utmTags: utm
        )
    }
}
