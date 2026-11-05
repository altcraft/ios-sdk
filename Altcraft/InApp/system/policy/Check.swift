//
//  Check.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import UIKit

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Collection of checks that determine whether an in-app campaign
/// can be displayed based on policy, time availability, deadline, placement,
/// and app version.
@available(iOSApplicationExtension, unavailable)
internal enum Check {

    /// Role-token presence checks.
    internal enum RToken {

        /// Checks whether a role token exists in the system.
        ///
        /// In-app campaigns are not allowed to be displayed when the SDK has
        /// no role token available (Android parity, `Check.RToken.canShow`).
        ///
        /// - Returns: `true` if a role token exists; `false` otherwise.
        static func canShow() async -> Bool {
            await CoreEnvironmentProvider.existRToken()
        }
    }

    /// Screen orientation checks.
    internal enum Orientation {

        /// Checks whether current screen orientation allows In-App display.
        ///
        /// In-App messages are not allowed in landscape orientation.
        @MainActor
        static func canShow() -> Bool {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            else {
                return UIScreen.main.bounds.height >= UIScreen.main.bounds.width
            }

            return !scene.interfaceOrientation.isLandscape
        }
    }

    /// Policy-based checks for display frequency and session limits.
    internal enum CommonPolicy {

        /// Validates whether an in-app campaign can be shown according to policy settings.
        ///
        /// The check includes:
        /// - trigger count limit
        /// - session display limit
        /// - minimal interval between displays
        ///
        /// - Parameter inApp: In-app placement campaign.
        /// - Returns: `true` if the campaign is allowed to be shown by policy.
        static func canShow(
            inApp: InAppModel.InApp
        ) -> Bool {
            guard let policy = inApp.options.policy else {
                return true
            }

            let lastOpenTime = InAppStoredVariables.shared.getInAppLastOpenTime()

            let triggerCount = InAppVariables.shared.getTriggerCount(
                inApp.actionTriggerType,
                inApp.actionTriggerName
            )

            let triggerLimitExceeded =
                policy.limitByTrigger > 0 &&
                triggerCount >= policy.limitByTrigger

            let sessionLimitExceeded =
                policy.limitBySession > 0 &&
                InAppVariables.shared.getOpenBySession() >= policy.limitBySession

            let minIntervalNotPassed =
                policy.minIntervalSec > 0 &&
                currentTimeMillis() < lastOpenTime + policy.minIntervalSec * 1000

            return !(triggerLimitExceeded || sessionLimitExceeded || minIntervalNotPassed)
        }
    }

    /// Policy-based checks using personal counters stored in the local database.
    internal enum PersonalPolicy {

        /// Checks whether the in-app campaign can be shown based on personal impressions limit.
        ///
        /// The check uses `inApp.smid`, because personal policy is stored per concrete
        /// in-app message, not per campaign id.
        ///
        /// - Parameter inApp: In-app placement campaign.
        /// - Returns: `true` if the campaign can be shown, otherwise `false`.
        static func canShow(
            inApp: InAppModel.InApp
        ) async -> Bool {
            let limit = inApp.options.impressionsLimit

            guard limit > 0 else {
                return true
            }

            let currentOpenCount = await InAppDAO.getInAppOpenCount(
                smid: inApp.smid
            ) ?? 0

            return Int(currentOpenCount) < limit
        }

        /// Updates personal open count for the given in-app.
        ///
        /// Increments the stored open counter.
        ///
        /// Personal policy rows are created when in-app placements are received,
        /// so this method does not create a default policy record.
        ///
        /// If the configured impressions limit is reached, the in-app campaign is removed
        /// from local storage.
        ///
        /// - Parameter inApp: Target in-app campaign.
        static func checkPersonalPolicy(
            inApp: InAppModel.InApp
        ) async {
            let currentOpenCount = await InAppDAO.getInAppOpenCount(
                smid: inApp.smid
            )

            let limit = inApp.options.impressionsLimit

            let newOpenCount = (currentOpenCount ?? 0) + 1

            await InAppDAO.incrementInAppOpenCount(
                smid: inApp.smid
            )

            if limit > 0 && Int(newOpenCount) >= limit {
                await InAppDAO.deleteInAppEntity(
                    companyId: Int32(inApp.companyId)
                )
            }
        }
    }

    /// Time-based checks for campaign availability.
    internal enum Availability {

        /// Checks whether the current moment matches the configured availability rules.
        ///
        /// The check includes:
        /// - years
        /// - months
        /// - month days
        /// - week days
        /// - week day order in month
        /// - time periods
        ///
        /// - Parameters:
        ///   - inApp: In-app placement campaign.
        ///   - nowMillis: Current time in milliseconds. Uses system time by default.
        /// - Returns: `true` if the current time is within the allowed schedule.
        static func canShow(
            inApp: InAppModel.InApp,
            nowMillis: Int64 = currentTimeMillis()
        ) -> Bool {
            guard let availability = inApp.options.availability else {
                return true
            }

            let timeZone = TimeZone(identifier: availability.tz)
                ?? TimeZone(secondsFromGMT: 0)
                ?? .current

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone

            let date = Date(timeIntervalSince1970: TimeInterval(nowMillis) / 1000.0)

            let currentHour = calendar.component(.hour, from: date)
            let currentMinute = calendar.component(.minute, from: date)
            let currentMinutesOfDay = currentHour * 60 + currentMinute

            let currentWday = mapWeekday(calendar.component(.weekday, from: date))
            let currentYear = calendar.component(.year, from: date)
            let currentMonth = calendar.component(.month, from: date)
            let currentMday = calendar.component(.day, from: date)

            let yearOk = availability.years.isEmpty || availability.years.contains(currentYear)
            let monthOk = availability.months.isEmpty || availability.months.contains(currentMonth)
            let mdayOk = availability.mdays.isEmpty || availability.mdays.contains(currentMday)
            let wdayOk = availability.wdays.isEmpty || availability.wdays.contains(currentWday)

            let wdayOrderOk = availability.wdayOrders.isEmpty || availability.wdayOrders.contains {
                matchesWeekdayOrderInMonth(
                    order: $0,
                    date: date,
                    calendar: calendar
                )
            }

            let periodOk = availability.periods.isEmpty || availability.periods.contains {
                matchesPeriod($0, currentMinutesOfDay: currentMinutesOfDay)
            }

            return yearOk && monthOk && mdayOk && wdayOk && wdayOrderOk && periodOk
        }

        /// Converts Foundation weekday value to SDK weekday format.
        ///
        /// Sunday is mapped to `0`, Monday to `1`, Saturday to `6`.
        ///
        /// - Parameter weekday: Foundation weekday value where Sunday is `1`.
        /// - Returns: Weekday number in SDK format.
        private static func mapWeekday(_ weekday: Int) -> Int {
            switch weekday {
            case 1: return 0
            case 2: return 1
            case 3: return 2
            case 4: return 3
            case 5: return 4
            case 6: return 5
            case 7: return 6
            default: return -1
            }
        }

        /// Checks whether current date matches configured weekday order in month.
        ///
        /// Rules:
        /// - `0` means the filter is disabled.
        /// - `1...5` mean first...fifth same weekday in the current month.
        /// - `-1` means last same weekday in the current month.
        /// - unknown values are treated as allowed to keep backend compatibility.
        ///
        /// - Parameters:
        ///   - order: Weekday order in month.
        ///   - date: Current date.
        ///   - calendar: Calendar configured with availability time zone.
        /// - Returns: `true` if current date matches the order.
        private static func matchesWeekdayOrderInMonth(
            order: Int,
            date: Date,
            calendar: Calendar
        ) -> Bool {
            if order == 0 {
                return true
            }

            switch order {
            case 1...5:
                var currentWeekIndex = 1
                var previousSameWeekday = date

                while let previousDate = calendar.date(
                    byAdding: .day,
                    value: -7,
                    to: previousSameWeekday
                ) {
                    let previousMonth = calendar.component(.month, from: previousDate)
                    let currentMonth = calendar.component(.month, from: date)

                    let previousYear = calendar.component(.year, from: previousDate)
                    let currentYear = calendar.component(.year, from: date)

                    if previousMonth != currentMonth || previousYear != currentYear {
                        break
                    }

                    currentWeekIndex += 1
                    previousSameWeekday = previousDate
                }

                return currentWeekIndex == order

            case -1:
                guard let nextSameWeekday = calendar.date(
                    byAdding: .day,
                    value: 7,
                    to: date
                ) else {
                    return true
                }

                let nextMonth = calendar.component(.month, from: nextSameWeekday)
                let currentMonth = calendar.component(.month, from: date)

                let nextYear = calendar.component(.year, from: nextSameWeekday)
                let currentYear = calendar.component(.year, from: date)

                return nextMonth != currentMonth || nextYear != currentYear

            default:
                return true
            }
        }

        /// Checks whether current time matches the specified time period.
        ///
        /// Supports both regular ranges and ranges crossing midnight.
        ///
        /// - Parameters:
        ///   - period: Configured availability period.
        ///   - currentMinutesOfDay: Current time as minutes from start of day.
        /// - Returns: `true` if current time is inside the period.
        private static func matchesPeriod(
            _ period: InAppModel.TimePeriod,
            currentMinutesOfDay: Int
        ) -> Bool {
            let from = period.from.minutesOfDay
            let to = period.to.minutesOfDay

            switch true {
            case from == to:
                return true
            case from < to:
                return currentMinutesOfDay >= from && currentMinutesOfDay < to
            default:
                return currentMinutesOfDay >= from || currentMinutesOfDay < to
            }
        }
    }

    /// Expiration checks for campaign lifetime.
    internal enum Deadline {

        /// Checks whether an in-app campaign is still valid by deadline and end time.
        ///
        /// If the campaign is expired, it is removed from the local database.
        ///
        /// - Parameter inApp: In-app placement campaign.
        /// - Returns: `true` if the campaign is still active.
        static func canShow(
            inApp: InAppModel.InApp
        ) async -> Bool {
            if inApp.deadline == 0 {
                return true
            }

            let currentTime = currentTimeMillis()

            if inApp.deadline < currentTime || inApp.options.endTime < currentTime {
                await InAppDAO.deleteInAppEntity(
                    companyId: Int32(inApp.companyId)
                )

                return false
            }

            return true
        }
    }

    /// Placement checks for campaign display location.
    internal enum Placement {

        /// Checks whether the current placement is allowed for an in-app campaign.
        ///
        /// - Parameter inApp: In-app placement campaign.
        /// - Returns: `true` if placement matches or no placement restrictions are configured.
        static func canShow(
            inApp: InAppModel.InApp
        ) -> Bool {
            let placements = inApp.options.placements

            return !(
                !placements.isEmpty &&
                !placements.contains(
                    InAppVariables.shared.getCurrentPlacement() ?? ""
                )
            )
        }
    }

    /// App version checks.
    internal enum Version {

        /// Checks whether the campaign can be shown for the current app version.
        ///
        /// Allows display when versions, condition, or current app version are missing.
        ///
        /// - Parameters:
        ///   - env: In-app module environment used to read app configuration.
        ///   - inApp: In-app placement campaign.
        /// - Returns: `true` if app version condition matches.
        static func canShow(
            env: InAppEnvironment,
            inApp: InAppModel.InApp
        ) async -> Bool {
            let appVersions = inApp.options.appVersions

            guard !appVersions.isEmpty else {
                return true
            }

            guard let condition = inApp.options.appVersionConditionRaw,
                  !condition.isEmpty else {
                return true
            }

            do {
                let appVersion = try await env.appVersion() ?? ""

                guard !appVersion.isEmpty else {
                    return true
                }

                return AppVersionMatcher.matches(
                    appVersion: appVersion,
                    appVersions: appVersions,
                    condition: condition
                )
            } catch {
                InAppLog.error(#function, error: error)
                return true
            }
        }
    }

    /// Subscription status checks.
     internal enum SubStatusCheck {

         /// Checks whether the current user is allowed to receive the in-app.
         ///
         /// Anonymous in-app campaigns are always allowed.
         ///
         /// Non-anonymous campaigns require the current user to have
         /// `InAppConstants.SubStatus.subscribed` status.
         ///
         /// - Parameter inApp: In-app placement campaign.
         /// - Returns: `true` if the campaign can be shown for the current user.
         static func canShow(
             inApp: InAppModel.InApp
         ) async -> Bool {
             if inApp.options.isAnonim {
                 return true
             }

             return await InAppSubscriptionProcess.shared.getInAppSubscriptionStatus()
         }
     }

    /// Checks whether an in-app campaign can be shown.
    ///
    /// The checks are executed sequentially and stop on the first failure,
    /// in the following order:
    /// - rToken presence (no role token — no in-app display)
    /// - availability (time-based schedule)
    /// - common policy (session, trigger, interval limits)
    /// - deadline (campaign expiration)
    /// - personal policy (impressions limit)
    /// - subscription status
    /// - app version
    /// - screen orientation
    ///
    /// - Parameter inApp: In-app campaign to validate.
    /// - Returns: `true` if the campaign passes all display checks.
    static func canShow(_ inApp: InAppModel.InApp) async -> Bool {
        let env = InAppEnvironment.fresh()
        guard await Check.RToken.canShow() else { return false }
        guard Check.Availability.canShow(inApp: inApp) else { return false }
        guard Check.CommonPolicy.canShow(inApp: inApp) else { return false }
        guard await Check.Deadline.canShow(inApp: inApp) else { return false }
        guard await Check.PersonalPolicy.canShow(inApp: inApp) else { return false }
        guard await Check.SubStatusCheck.canShow(inApp: inApp) else { return false }
        guard await Check.Version.canShow(env: env, inApp: inApp) else { return false }
        guard await Check.Orientation.canShow() else { return false }

        return true
    }
}

// MARK: - Helpers

private extension InAppModel.TimePoint {

    /// Total minutes from the start of day.
    var minutesOfDay: Int {
        hour * 60 + min
    }
}

/// Returns the current time in milliseconds since the Unix epoch.
private func currentTimeMillis() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
}
