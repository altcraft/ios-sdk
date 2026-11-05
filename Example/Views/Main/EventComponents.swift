//
//  EventComponents.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush
import AltcraftInApp
import AltcraftProfile
import AltcraftTarget
import SwiftUI

private let SuccessColor = Color(hex: 0x33FF5F)
private let ErrorColor = Color(hex: 0xFFFF6E7F)
private let NormalColor = Color.black

private let TextPrimary = Color(hex: 0x0F172A)
private let TextSecondary = Color(hex: 0x475569)
private let BorderColor = Color(hex: 0xE2E8F0)
private let CardBackground = Color.white

private let httpCodeKey = "http_code"
private let tokenKey = "token"

/// Event timeline list.
struct MainEventsListView: View {
    var events: [IdentifiableEvent]

    private var visibleEvents: [IdentifiableEvent] {
        Array(events.suffix(5).reversed())
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(visibleEvents.enumerated()), id: \.element.id) { index, identifiable in
                MainEventsView(
                    eventMessage: identifiable.event.message ?? "",
                    funcName: identifiable.event.function,
                    eventDate: identifiable.event.date,
                    eventValue: identifiable.event.value,
                    sdkEvent: identifiable.event.event,
                    isErrorEvent: identifiable.event is ErrorEvent,
                    isFirst: index == 0,
                    isLast: index == visibleEvents.count - 1
                )
            }
        }
        .padding(.top, 5)
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity)
        .background(CardBackground)
        .cornerRadius(15)
        .padding(.horizontal, 5)
    }
}

/// Main screen events section.
struct MainEventsView: View {
    var eventMessage: String
    var funcName: String? = nil
    var eventDate: Date? = nil
    var eventValue: [String: Any]? = nil
    var sdkEvent: (any SDKEvent)? = nil
    var isErrorEvent: Bool = false
    var isFirst: Bool = false
    var isLast: Bool = false

    private var cleanFunctionName: String {
        (funcName ?? "unknown")
            .replacingOccurrences(of: "()", with: "")
    }

    private var isPushProviderSet: Bool {
        (sdkEvent as? PushModuleEvents) == .pushProviderSet
    }

    private var formattedDate: String? {
        guard let eventDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: eventDate)
    }

    private var dateText: String {
        formattedDate?.components(separatedBy: " ").first ?? "--"
    }

    private var timeText: String {
        guard let formattedDate else { return "--" }
        let parts = formattedDate.components(separatedBy: " ")
        return parts.count > 1 ? parts.dropFirst().joined(separator: " ") : "--"
    }

    private var statusColor: Color {
        if isPushProviderSet {
            return SuccessColor
        }

        if isErrorEvent {
            return ErrorColor
        }
        
        if let httpCode = httpCode {
            switch httpCode {
            case 200...299, 304: return SuccessColor
            default: return ErrorColor
            }
        }

        return NormalColor
    }

    private var httpCode: Int? {
        if let valueCode = eventValue?[httpCodeKey] {
            if let intCode = valueCode as? Int {
                return intCode
            }

            if let stringCode = valueCode as? String {
                return Int(stringCode)
            }

            if let doubleCode = valueCode as? Double {
                return Int(doubleCode)
            }

            if let floatCode = valueCode as? Float {
                return Int(floatCode)
            }
        }

        let patterns = [
            #""\#(httpCodeKey)"\s*:\s*(\d{3})"#,
            #"\#(httpCodeKey)\s*[:=]\s*(\d{3})"#,
            #""httpCode"\s*:\s*(\d{3})"#,
            #"httpCode\s*[:=]\s*(\d{3})"#,
            #""code"\s*:\s*(\d{3})"#,
            #"code\s*[:=]\s*(\d{3})"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

            let range = NSRange(eventMessage.startIndex..<eventMessage.endIndex, in: eventMessage)

            if let match = regex.firstMatch(in: eventMessage, range: range),
               let codeRange = Range(match.range(at: 1), in: eventMessage) {
                return Int(eventMessage[codeRange])
            }
        }

        return nil
    }

    private var statusBadgeText: String? {
        if isPushProviderSet {
            return getTokenLastThreeSymbols()
        }

        if let httpCode {
            return "\(httpCode)"
        }

        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TimelineIndicatorView(
                    color: statusColor,
                    isFirst: isFirst,
                    isLast: isLast
                )
                .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(dateText)
                        .foregroundColor(TextSecondary)
                        .font(.system(size: 8.5, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(timeText)
                        .foregroundColor(TextPrimary)
                        .font(.system(size: 8.5, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 82, alignment: .leading)
                .padding(.leading, 5)

                VStack(alignment: .leading, spacing: 1) {
                    Text(cleanFunctionName)
                        .foregroundColor(TextPrimary)
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(eventMessage.isEmpty ? "SDK event" : eventMessage)
                        .foregroundColor(TextSecondary)
                        .font(.system(size: 9))
                        .fontWeight(.regular)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .padding(.vertical, 8)

                if let statusBadgeText {
                    StatusBadgeView(
                        text: statusBadgeText,
                        color: statusColor
                    )
                    .fixedSize()
                } else {
                    Text("›")
                        .foregroundColor(TextSecondary)
                        .font(.system(size: 20))
                        .fontWeight(.regular)
                        .frame(width: 12)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .padding(.horizontal, 12)

            if !isLast {
                Rectangle()
                    .fill(BorderColor.opacity(0.7))
                    .frame(height: 1)
                    .padding(.leading, 92)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }

    /// Returns the last token characters for display, or `nil`.
    private func getTokenLastThreeSymbols() -> String? {
        if let token = eventValue?[tokenKey] as? String,
           token.isEmpty == false {
            return String(token.suffix(3))
        }

        let patterns = [
            #""\#(tokenKey)"\s*:\s*"([^"]+)""#,
            #"\#(tokenKey)\s*[:=]\s*([A-Za-z0-9_\-:.]+)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

            let range = NSRange(eventMessage.startIndex..<eventMessage.endIndex, in: eventMessage)

            if let match = regex.firstMatch(in: eventMessage, range: range),
               let tokenRange = Range(match.range(at: 1), in: eventMessage) {
                let token = String(eventMessage[tokenRange])
                return token.isEmpty ? nil : String(token.suffix(3))
            }
        }

        return nil
    }
}

/// Timeline status indicator.
struct TimelineIndicatorView: View {
    var color: Color
    var isFirst: Bool
    var isLast: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : BorderColor)
                    .frame(width: 1, height: 27)

                Rectangle()
                    .fill(isLast ? Color.clear : BorderColor)
                    .frame(width: 1, height: 27)
            }

            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
        }
        .frame(width: 14, height: 54)
    }
}

/// Status badge.
struct StatusBadgeView: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .foregroundColor(.black)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .cornerRadius(6)
    }
}
