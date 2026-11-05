//
//  Presenter.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Presents in-app campaigns and waits until they are shown and dismissed.
@available(iOSApplicationExtension, unavailable)
internal enum Presenter {

    /// Prepared in-app content required for display.
    private struct PreparedContent {
        let content: String
        let images: [String]
        let staticBundle: InAppModel.InAppStaticProcess
        let displayType: InAppDisplayType
    }

    /// Presents an in-app campaign if it passes placement and runtime checks.
    ///
    /// For delayed presentation, availability, policy, deadline,
    /// personal policy, and app version are revalidated before showing.
    ///
    /// - Parameters:
    ///   - inApp: In-app campaign to present.
    ///   - delayTask: `true` if presentation was triggered by delayed task.
    ///   - trigger: Trigger that started the in-app campaign.
    @MainActor
    static func present(
        _ inApp: InAppModel.InApp,
        delayTask: Bool = false,
        trigger: InAppModel.InAppTrigger? = nil
    ) async {
        await InAppPresentationQueue.shared.waitForTurn()
        defer {
            Task {
                await InAppPresentationQueue
                    .shared
                    .finishPresentation()
            }
        }

        // The wait may have been cut short by task cancellation; a cancelled
        // task must release the slot instead of presenting.
        guard !Task.isCancelled else {
            return
        }

        guard await canPresent(
            inApp,
            delayTask: delayTask,
            trigger: trigger
        ) else {
            return
        }

        guard let content = await loadInAppContent(inApp: inApp) else {
            return
        }

        await withCheckedContinuation { continuation in
            /// Box resuming an awaiting continuation exactly once.
            final class ResumeBox {
                var didResume = false

                /// Resumes the continuation only once.
                func resumeOnce(
                    _ continuation: CheckedContinuation<Void, Never>
                ) {
                    guard !didResume else {
                        return
                    }

                    didResume = true
                    continuation.resume()
                }
            }

            let box = ResumeBox()

            Task { @MainActor in
                let started = await InAppPresenter.show(
                    companyId: inApp.companyId,
                    smid: inApp.smid,
                    html: content.content,
                    imageURLs: content.images,
                    staticBundle: content.staticBundle,
                    displayType: content.displayType,
                    onShown: {
                        Task {
                            if !inApp.isTest,
                               let trigger {
                                await InAppVariables
                                    .shared
                                    .updateInAppVariables(
                                        inApp: inApp,
                                        trigger: trigger
                                    )
                            }
                        }
                    },
                    onClose: {
                        box.resumeOnce(continuation)
                    }
                )

                if !started {
                    box.resumeOnce(continuation)
                }
            }
        }
    }

    /// Checks whether an in-app campaign can be presented.
    ///
    /// Test campaigns are always allowed.
    /// Non-test campaigns require a trigger.
    ///
    /// For non-delayed presentation only placement is revalidated.
    /// For delayed presentation all runtime checks are revalidated.
    ///
    /// - Parameters:
    ///   - inApp: In-app campaign to validate.
    ///   - delayTask: `true` if presentation was triggered by delayed task.
    ///   - trigger: Trigger that started the in-app campaign.
    /// - Returns: `true` if campaign can be presented.
    private static func canPresent(
        _ inApp: InAppModel.InApp,
        delayTask: Bool,
        trigger: InAppModel.InAppTrigger?
    ) async -> Bool {
        if inApp.isTest {
            return true
        }

        guard trigger != nil else {
            return false
        }

        guard Check.Placement.canShow(inApp: inApp) else {
            return false
        }

        guard delayTask else {
            return await Check.Orientation.canShow()
        }

        return await Check.canShow(inApp)
    }

    /// Loads and parses in-app content from the content URL.
    ///
    /// - Parameter inApp: In-app campaign.
    /// - Returns: Parsed in-app content response, or `nil` on failure.
    private static func loadContent(
        inApp: InAppModel.InApp
    ) async -> InAppModel.InAppContent? {
        guard let url = URL(string: inApp.contentUrl) else {
            InAppLog.error(
                #function,
                error: CoreEvents.invalidRequestUrl,
                eventValue: [InAppConstants.MapKeys.url: inApp.contentUrl]
            )
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            return try JSONDecoder().decode(
                InAppModel.InAppContent.self,
                from: data
            )
        } catch {
            InAppLog.error(#function, error: error)
            return nil
        }
    }

    /// Loads and prepares in-app content for display.
    ///
    /// Loads static resources, downloads content,
    /// preloads images from the content response,
    /// resolves native display type,
    /// and builds prepared display data.
    ///
    /// Important:
    /// if at least one image fails to preload, this method returns `nil`.
    /// That prevents `InAppPresenter.show(...)` from being called and blocks
    /// displaying an in-app with missing images.
    ///
    /// Failed image URLs are joined with `;` and sent to the server
    /// as the `message` field of in-app error event.
    ///
    /// - Parameter inApp: In-app campaign.
    /// - Returns: Prepared in-app content, or `nil` on failure.
    private static func loadInAppContent(
        inApp: InAppModel.InApp
    ) async -> PreparedContent? {
        guard let staticBundle = await InAppStaticProcess.shared.getInAppStatic() else {
            let error = InAppModuleEvents.inAppStaticErrorLoad

            await InAppEventProcess.shared.sendErrorInAppEvent(
                smid: inApp.smid,
                error: error.message
            )

            InAppLog.error(
                #function,
                error: error
            )

            return nil
        }

        guard let content = await loadContent(inApp: inApp) else {
            let error = InAppModuleEvents.inAppContentErrorLoad

            await InAppEventProcess.shared.sendErrorInAppEvent(
                smid: inApp.smid,
                error: error.message
            )

            InAppLog.error(
                #function,
                error: error
            )

            return nil
        }

        let inAppType = inApp.type.lowercased()

        if inAppType == InAppConstants.InAppType.json {
            InAppEmitter.shared.emit(json: content.content)
            return nil
        }

        let imagePreloadResult = await InAppImagePreloader.imagePreload(
            urls: content.images
        )

        guard imagePreloadResult.isSuccess else {
            let failedURLsMessage = imagePreloadResult.failedURLs
                .joined(separator: ";")

            await InAppEventProcess.shared.sendErrorInAppEvent(
                smid: inApp.smid,
                error: failedURLsMessage
            )

            InAppLog.error(
                #function,
                error: InAppModuleEvents.errorInAppImageLoad,
                eventValue: ["urls": failedURLsMessage]
            )

            return nil
        }

        let isCustom = inAppType == InAppConstants.InAppType.custom

        return PreparedContent(
            content: content.content,
            images: content.images,
            staticBundle: InAppModel.InAppStaticProcess(
                inAppLibraryJs: staticBundle.inAppLibraryJs,
                blockJs: isCustom ? "" : staticBundle.blockJs,
                blockCss: isCustom ? "" : staticBundle.blockCss
            ),
            displayType: InAppDisplayType.from(content.displayType)
        )
    }
}

// MARK: - Unit Test Hooks

@available(iOSApplicationExtension, unavailable)
extension Presenter {

    /// Test hook: loads in-app content through the production pipeline.
    ///
    /// - Parameter inApp: In-app campaign to load.
    /// - Returns: Processed content, or `nil` when loading fails.
    internal static func test_presenter_loadContent(
        inApp: InAppModel.InApp
    ) async -> InAppModel.InAppContent? {
        await loadContent(inApp: inApp)
    }
}
