//
//  AltcraftPushReceiver.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

@preconcurrency import UserNotifications
import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Handles Altcraft push notifications inside a Notification Service Extension.
/// Responsible for: delivery event tracking, action button creation,
/// category registration, and media attachment loading.
///
/// Concurrency design:
/// - Every push is processed in its own isolated context (handler + content),
///   so concurrent pushes can never overwrite or read each other's state.
/// - The completion handler is invoked at most once per push, regardless of
///   whether delivery happens through the processing task or through
///   `serviceExtensionTimeWillExpire()`.
/// - The only shared state is the in-flight registry, guarded by a lock,
///   which justifies the `@unchecked Sendable` conformance.
@objcMembers
final class AltcraftPushReceiver: NSObject, @unchecked Sendable {

    /// Isolated state of a single push being processed.
    ///
    /// `UNMutableNotificationContent` is not thread-safe, so every access —
    /// mutations from the processing task and the final read by the
    /// completion handler — is serialized with the context lock. The
    /// expiration path (`serviceExtensionTimeWillExpire()`) may run on the
    /// main thread while the processing task is still mutating the content
    /// (e.g. during a slow media download), which is exactly why all
    /// content access must hold the lock.
    private final class PushContext: @unchecked Sendable {

        /// Completion handler registered by the system for this push.
        let handler: (UNNotificationContent) -> Void

        /// Mutable content copy being prepared for this push.
        let content: UNMutableNotificationContent

        /// Guards `isDelivered` and all `content` access.
        private let lock = NSLock()

        /// Whether the completion handler has already been invoked.
        private var isDelivered = false

        /// Indicates whether the completion handler was already invoked.
        var delivered: Bool {
            lock.lock()
            defer { lock.unlock() }
            return isDelivered
        }

        /// - Parameters:
        ///   - handler: System completion handler for this push.
        ///   - content: Mutable content copy prepared for this push.
        init(
            handler: @escaping (UNNotificationContent) -> Void,
            content: UNMutableNotificationContent
        ) {
            self.handler = handler
            self.content = content
        }

        /// Applies a mutation to the content while holding the context lock.
        ///
        /// Mutations are ignored once the push has been delivered (e.g. a
        /// media download finishing after `serviceExtensionTimeWillExpire()`).
        ///
        /// - Parameter body: Closure mutating the content.
        func mutate(_ body: (UNMutableNotificationContent) -> Void) {
            lock.lock()
            defer { lock.unlock() }
            guard !isDelivered else { return }
            body(content)
        }

        /// Invokes the completion handler exactly once with the final content.
        ///
        /// Subsequent calls — e.g. from `serviceExtensionTimeWillExpire()`
        /// after the processing task has finished, or vice versa — are ignored.
        /// The system callback runs while the lock is held so it always reads
        /// a consistent content snapshot and cannot interleave with a
        /// late mutation from the processing task.
        func deliver() {
            lock.lock()
            if isDelivered {
                lock.unlock()
                return
            }
            isDelivered = true
            handler(content)
            lock.unlock()
        }
    }

    /// Serializes access to the in-flight registry.
    private let lock = NSLock()

    /// Pushes currently being processed, in arrival order (FIFO).
    ///
    /// `serviceExtensionTimeWillExpire()` has no request identifier, so on
    /// expiration the oldest push that has not been delivered yet is
    /// finalized. APNs delivers bursts in order, which makes this
    /// correlation reliable in practice.
    private var inFlight: [PushContext] = []

    /// Checks whether a push notification belongs to Altcraft.
    ///
    /// - Parameter request: The incoming `UNNotificationRequest`.
    /// - Returns: `true` if the push contains Altcraft signature fields, otherwise `false`.
    func isAltcraftPush(_ request: UNNotificationRequest) -> Bool {
        (request.content.userInfo as? [String: Any])?["_ac_push"] != nil
    }

    /// Processes an Altcraft push inside the NSE: records the delivery event
    /// for a first-seen message UID, attaches media, creates categories and
    /// actions, and returns final content.
    ///
    /// A repeated message UID is displayed as usual but its delivery event is
    /// not sent again. The push state is fully isolated in its own context, so
    /// concurrent pushes processed by the extension process cannot interfere
    /// with each other. The handler is invoked exactly once — with the modified
    /// content on success, or with the original content if processing fails or
    /// the content cannot be mutated.
    ///
    /// - Parameters:
    ///   - request: The notification request received by NSE.
    ///   - handler: Completion handler invoked with the final notification content.
    func takePush(
        _ request: UNNotificationRequest,
        withContentHandler handler: @escaping (UNNotificationContent) -> Void
    ) {
        guard let content = request.content.mutableCopy()
                as? UNMutableNotificationContent
        else {
            handler(request.content)
            return
        }

        let context = PushContext(handler: handler, content: content)
        register(context)

        Task {
            let uid = request.content.userInfo[
                PushConstants.UserInfoKeys.uid
            ] as? String

            if let uid = uid {
                if await PushMessageDAO.shouldSendDeliveryEvent(uid: uid) {
                    await PushEventProcess.shared.createPushEvent(
                        uid: uid,
                        type: PushConstants.PushEvents.delivery
                    )
                } else {
                    PushLog.event(
                        #function,
                        event: PushModuleEvents.duplicatePushMessage,
                        eventValue: ["uid": uid]
                    )
                }
            } else {
                await PushEventProcess.shared.createPushEvent(
                    uid: nil, type: PushConstants.PushEvents.delivery
                )
            }

            let categoryID = await makeCategory(from: request.content.userInfo)
            context.mutate { $0.categoryIdentifier = categoryID }

            if let attachment = await loadNotificationAttachment(
                for: request
            ) {
                context.mutate { $0.attachments = [attachment] }
            }

            PushLog.event(
                #function,
                event: PushModuleEvents.pushIsPosted
            )

            context.deliver()
            unregister(context)
        }
    }

    /// Creates a notification category with interactive buttons extracted from push payload.
    ///
    /// The resulting category is merged into the existing set instead of
    /// replacing it: `setNotificationCategories` overwrites the whole set, so
    /// a plain replacement would silently drop the host application's own
    /// categories and disable its notification action buttons after the
    /// first Altcraft push. The previous Altcraft category (if any) is
    /// replaced by identifier; unrelated categories are kept untouched.
    ///
    /// - Parameter info: `userInfo` dictionary from push.
    /// - Returns: The registered category identifier.
    private func makeCategory(
        from info: [AnyHashable: Any]
    ) async -> String {
        let categoryKey = PushConstants.categoryForRichPush
        var actions: [UNNotificationAction] = []

        if
            let json = info[PushConstants.UserInfoKeys.buttons] as? String,
            let data = json.data(using: .utf8),
            let arr = try? JSONDecoder().decode([[String: String]].self, from: data)
        {
            actions = arr.enumerated().compactMap { index, btn in
                guard let title = btn["label"] else { return nil }
                return UNNotificationAction(
                    identifier: "button\(index)",
                    title: title,
                    options: [.foreground]
                )
            }
        }

        let category = UNNotificationCategory(
            identifier: categoryKey,
            actions: actions,
            intentIdentifiers: [],
            options: []
        )

        let center = UNUserNotificationCenter.current()

        let existing = await center.notificationCategories()

        let merged = existing
            .filter { $0.identifier != categoryKey }
            .union([category])

        if merged != existing {
            center.setNotificationCategories(merged)
        }

        return categoryKey
    }

    /// Loads a remote image specified in the notification payload and builds
    /// a notification attachment from it.
    ///
    /// The attachment is constructed without touching the notification
    /// content; the caller attaches it under the push context lock.
    ///
    /// - Parameter req: The original notification request containing the media URL in `userInfo`.
    /// - Returns: A ready attachment, or `nil` when the media is missing or the download fails.
    private func loadNotificationAttachment(
        for req: UNNotificationRequest
    ) async -> UNNotificationAttachment? {
        let media = (req.content.userInfo as? [String: Any])?[
            PushConstants.UserInfoKeys.media
        ] as? String

        guard let media, let url = URL(string: media) else {
            return nil
        }

        do {
            let request = URLRequest(url: url)
            let (data, _) = try await URLSession.shared.dataAsync(
                for: request
            )

            guard !data.isEmpty else {
                PushLog.error(#function, error: PushModuleEvents.errorMediaDownload)
                return nil
            }

            return try buildImageAttachment(from: data)
        } catch {
            PushLog.error(#function, error: error)
            return nil
        }
    }

    /// Builds a notification attachment from downloaded image data.
    ///
    /// - Parameter data: Downloaded image data.
    /// - Returns: Attachment ready to be added to notification content.
    /// - Throws: File / Data / UNNotificationAttachment errors.
    private func buildImageAttachment(from data: Data) throws -> UNNotificationAttachment {
        let format = ImageFormat(data: data)
        let ext = format?.fileExtension ?? "jpg"

        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                UUID().uuidString, isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )

        let dest = dir.appendingPathComponent("image.\(ext)")
        try data.write(to: dest)

        let options = format?.utiHint.map {
            [UNNotificationAttachmentOptionsTypeHintKey: $0]
        }

        return try UNNotificationAttachment(
            identifier: "img", url: dest, options: options
        )
    }

    /// Builds an image attachment from data and attaches it to the mutable
    /// notification content.
    ///
    /// - Parameters:
    ///   - data: Downloaded image data.
    ///   - content: Mutable notification content to update with attachment.
    /// - Throws: File / Data / UNNotificationAttachment errors.
    func applyImageAttachment(
        from data: Data,
        to content: UNMutableNotificationContent
    ) throws {
        content.attachments = [try buildImageAttachment(from: data)]
    }

    /// Called by the system when the NSE execution time is about to expire.
    ///
    /// Delivers the best available content of the oldest push that has not
    /// been delivered yet. A push whose handler was already invoked by its
    /// processing task is skipped, so the handler is never called twice.
    func serviceExtensionTimeWillExpire() {
        lock.lock()
        let context = inFlight.first { !$0.delivered }
        lock.unlock()

        context?.deliver()
    }

    /// Adds a push to the in-flight registry.
    ///
    /// - Parameter context: Context of the push that started processing.
    private func register(_ context: PushContext) {
        lock.lock()
        defer { lock.unlock() }
        inFlight.append(context)
    }

    /// Removes a finished push from the in-flight registry.
    ///
    /// - Parameter context: Context of the push that finished processing.
    private func unregister(_ context: PushContext) {
        lock.lock()
        defer { lock.unlock() }
        inFlight.removeAll { $0 === context }
    }
}
