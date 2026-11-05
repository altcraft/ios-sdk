//
//  InAppEventProcessing.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import UIKit
import WebKit

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Handles in-app events received from JavaScript inside WebView.
///
/// Decodes incoming event payloads,
/// sends SDK in-app events,
/// opens links,
/// handles ready and slide layout states,
/// and closes the in-app when needed.
@available(iOSApplicationExtension, unavailable)
@MainActor
internal enum InAppEventProcessing {

    /// Raw event envelope used to detect the event type before decoding
    /// its type-specific payload.
    private struct RawEventTypeEnvelope: Decodable {
        let type: String
    }

    /// Event envelope used only for slide layout readiness.
    private struct SlideReadyEnvelope: Decodable {
        let type: String
        let payload: SlideReadyPayload
    }

    /// Layout payload received from JavaScript for slide-up containers.
    ///
    /// Values are provided in CSS pixels. In a correctly configured `WKWebView`,
    /// CSS pixels correspond to UIKit points.
    internal struct SlideReadyPayload: Decodable {
        let height: CGFloat
        let paddingTop: CGFloat
        let paddingBottom: CGFloat
        let position: SlidePosition

        /// JSON coding keys for the parent model.
        private enum CodingKeys: String, CodingKey {
            case height
            case paddingTop
            case paddingBottom
            case position
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            height = try container.decode(CGFloat.self, forKey: .height)
            paddingTop = try container.decodeIfPresent(
                CGFloat.self,
                forKey: .paddingTop
            ) ?? 0
            paddingBottom = try container.decodeIfPresent(
                CGFloat.self,
                forKey: .paddingBottom
            ) ?? 0
            position = try container.decodeIfPresent(
                SlidePosition.self,
                forKey: .position
            ) ?? .bottom
        }
    }

    /// Vertical position of a slide-up container.
    internal enum SlidePosition: String, Decodable {
        case top
        case bottom
    }

    /// JavaScript event type used for slide layout readiness.
    private static let slideReadyEventType = "slideReady"

    /// Processes an in-app event received from JavaScript.
    ///
    /// - Parameters:
    ///   - data: Raw JSON event payload received from JavaScript.
    ///   - webView: Web view containing the in-app message.
    ///   - smid: Send Message ID associated with the current in-app message.
    static func process(
        data: String,
        webView: WKWebView,
        smid: String
    ) {
        guard let rawData = data.data(using: .utf8) else {
            InAppLog.error(
                #function,
                error: InAppModuleEvents.inAppEventRequestDataIsNil
            )
            return
        }

        do {
            let rawEvent = try JSONDecoder().decode(
                RawEventTypeEnvelope.self,
                from: rawData
            )

            if rawEvent.type == slideReadyEventType {
                let slideEvent = try JSONDecoder().decode(
                    SlideReadyEnvelope.self,
                    from: rawData
                )

                webView.parentViewController?
                    .asInAppContainerViewController?
                    .applySlideReady(slideEvent.payload)

                return
            }

            let event = try JSONDecoder().decode(
                InAppModel.InAppEventProcess.self,
                from: rawData
            )

            event.type.handleInAppInteraction(
                webView: webView,
                payload: event.payload
            )

            if event.type == .ready {
                webView.parentViewController?
                    .asInAppContainerViewController?
                    .markJavaScriptReadyAndSendInsets()

                return
            }

            let eventData = buildInAppEventData(
                type: event.type,
                payload: event.payload
            )

            Task {
                await InAppEventProcess.shared.createInAppEvent(
                    smid: smid,
                    type: event.type,
                    data: eventData
                )
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Builds normalized in-app event payload.
    ///
    /// Adds SDK error code `400` for JavaScript error events.
    ///
    /// - Parameters:
    ///   - type: In-app event type.
    ///   - payload: Original event payload.
    /// - Returns: Normalized event payload.
    private static func buildInAppEventData(
        type: InAppModel.InAppEventType,
        payload: RequestModel.InAppEventData?
    ) -> RequestModel.InAppEventData? {
        switch type {
        case .error:
            return RequestModel.InAppEventData(
                href: payload?.href,
                code: 400,
                message: payload?.message
            )

        case .delivery, .show, .click, .close, .ready:
            return payload
        }
    }
}

@MainActor
private extension InAppModel.InAppEventType {

    /// Applies UI side effects for the current in-app event type.
    ///
    /// - Parameters:
    ///   - webView: Web view containing the in-app message.
    ///   - payload: Optional event payload.
    func handleInAppInteraction(
        webView: WKWebView,
        payload: RequestModel.InAppEventData?
    ) {
        if let href = payload?.href,
           let url = URL(string: href) {
            UIApplication.shared.open(url)
        }

        switch self {
        case .click, .close:
            webView.parentViewController?
                .asInAppContainerViewController?
                .close()

        case .delivery, .show, .error, .ready:
            break
        }
    }
}

#if DEBUG
@available(iOSApplicationExtension, unavailable)
extension InAppEventProcessing {

    /// Test hook: builds in-app event data from the given type and payload.
    ///
    /// - Parameters:
    ///   - type: In-app event type.
    ///   - payload: Raw event payload.
    /// - Returns: Encoded event data, or `nil` when the payload cannot be encoded.
    static func test_buildInAppEventData(
        type: InAppModel.InAppEventType,
        payload: RequestModel.InAppEventData?
    ) -> RequestModel.InAppEventData? {
        buildInAppEventData(
            type: type,
            payload: payload
        )
    }
}
#endif

