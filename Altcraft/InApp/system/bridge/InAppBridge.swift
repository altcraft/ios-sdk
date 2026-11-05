//
//  InAppBridge.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import WebKit

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// WebView → native bridge for In-App events.
@available(iOSApplicationExtension, unavailable)
internal final class InAppBridge: NSObject, WKScriptMessageHandler {

    /// Callback with raw event JSON.
    private let onEvent: (String) -> Void

    /// Creates bridge with event callback.
    ///
    /// - Parameter onEvent: Callback with raw event JSON.
    init(onEvent: @escaping (String) -> Void) {
        self.onEvent = onEvent
    }

    /// Called by the system when JavaScript sends a message via the bridge.
    ///
    /// String payloads are forwarded unchanged. Dictionary and array payloads
    /// are serialized to JSON so the native event decoder receives one common
    /// representation.
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        if let eventJson = message.body as? String {
            onEvent(eventJson)
            return
        }

        guard JSONSerialization.isValidJSONObject(message.body),
              let data = try? JSONSerialization.data(withJSONObject: message.body),
              let eventJson = String(data: data, encoding: .utf8)
        else {
            return
        }

        onEvent(eventJson)
    }
}

#if DEBUG
@available(iOSApplicationExtension, unavailable)
extension InAppBridge {

    /// Test hook: feeds a bridge message body into event processing.
    ///
    /// - Parameter body: Message body; only string JSON payloads are processed.
    func test_receive(
        body: Any
    ) {
        if let eventJson = body as? String {
            onEvent(eventJson)
        }
    }
}
#endif

