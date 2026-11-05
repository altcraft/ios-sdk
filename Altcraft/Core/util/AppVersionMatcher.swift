//
//  AppVersionMatcher.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Utility for checking whether the current application version matches
/// at least one target version by the specified operator.
///
/// Version parsing rules:
/// - text prefix before the first digit is ignored, for example `v1.2.3`;
/// - only the part before the first space is used;
/// - version parts are separated by dots;
/// - only the first three numeric parts are compared;
/// - everything after `-` inside a version part is ignored;
/// - parsing stops when a part cannot be parsed as a number;
/// - missing version parts are treated as zeroes;
/// - trailing zero in the last parsed part is ignored.
///
/// Examples:
/// - `v1.2.3` becomes `[1, 2, 3]`;
/// - `version 1.2.0` becomes `[1, 2]`;
/// - `v4.3.1.1.213361` becomes `[4, 3, 1]`;
/// - `1.2.3-beta` becomes `[1, 2, 3]`.
@_spi(_Altcraft) public enum AppVersionMatcher {
    /// Supported version comparison operators.
    public enum Operator: String {
        case equal = "equal"
        case notEqual = "not_equal"
        case greaterThan = "greater_than"
        case lessThan = "less_than"
        case greaterEqual = "greater_e"
        case lessEqual = "less_e"

        /// Returns operator by raw value.
        ///
        /// - Parameter value: Raw operator value.
        /// - Returns: Parsed operator or `nil`.
        public static func fromValue(_ value: String?) -> Operator? {
            guard let value else { return nil }

            return Operator.allCases.first {
                $0.rawValue.caseInsensitiveCompare(value) == .orderedSame
            }
        }
    }

    /// Returns `true` when `appVersion` matches at least one version
    /// from `appVersions` using the specified operator.
    ///
    /// Example:
    /// ```swift
    /// AppVersionMatcher.matches(
    ///     appVersion: "v1.2.4",
    ///     appVersions: ["v1.2.3"],
    ///     operator: .greaterThan
    /// )
    /// ```
    ///
    /// In this example the result is `true`, because `1.2.4 > 1.2.3`.
    public static func matches(
        appVersion: String,
        appVersions: [String],
        operator comparisonOperator: Operator
    ) -> Bool {
        appVersions.contains { version in
            let result = compare(appVersion, version)

            switch comparisonOperator {
            case .equal:
                return result == 0
            case .notEqual:
                return result != 0
            case .greaterThan:
                return result > 0
            case .lessThan:
                return result < 0
            case .greaterEqual:
                return result >= 0
            case .lessEqual:
                return result <= 0
            }
        }
    }

    /// Returns `true` when `appVersion` matches at least one version
    /// from `appVersions` using the raw operator value.
    ///
    /// - Parameters:
    ///   - appVersion: Current application version.
    ///   - appVersions: Target application versions.
    ///   - condition: Raw comparison condition.
    /// - Returns: `true` if comparison succeeds.
    public static func matches(
        appVersion: String,
        appVersions: [String],
        condition: String
    ) -> Bool {
        guard let comparisonOperator = Operator.fromValue(condition) else {
            return true
        }

        return matches(
            appVersion: appVersion,
            appVersions: appVersions,
            operator: comparisonOperator
        )
    }

    /// Parses raw version string into numeric version parts.
    ///
    /// - Parameter rawVersion: Raw version string.
    /// - Returns: Parsed numeric version parts.
    private static func parse(_ rawVersion: String) -> [Int] {
        guard let firstDigitIndex = rawVersion.firstIndex(where: { $0.isNumber }) else {
            return []
        }

        let raw = String(rawVersion[firstDigitIndex...])
            .components(separatedBy: " ")
            .first ?? ""

        let parts = raw.components(separatedBy: ".")
        var result: [Int] = []

        for (index, part) in parts.enumerated() {
            guard index < 3 else {
                break
            }

            let numericPart = part
                .components(separatedBy: "-")
                .first?
                .prefix { $0.isNumber } ?? ""

            guard !numericPart.isEmpty,
                  let number = Int(numericPart) else {
                break
            }

            if index == parts.count - 1 && number == 0 {
                break
            }

            result.append(number)
        }

        return result
    }

    /// Compares two raw version strings.
    ///
    /// - Parameters:
    ///   - leftRaw: Left version.
    ///   - rightRaw: Right version.
    /// - Returns: `1` if left is greater, `-1` if right is greater, `0` if equal.
    private static func compare(
        _ leftRaw: String,
        _ rightRaw: String
    ) -> Int {
        var left = parse(leftRaw)
        var right = parse(rightRaw)

        while left.count < 3 {
            left.append(0)
        }

        while right.count < 3 {
            right.append(0)
        }

        for index in 0..<3 {
            if left[index] > right[index] {
                return 1
            }

            if left[index] < right[index] {
                return -1
            }
        }

        return 0
    }
}

private extension AppVersionMatcher.Operator {
    static var allCases: [AppVersionMatcher.Operator] {
        [
            .equal,
            .notEqual,
            .greaterThan,
            .lessThan,
            .greaterEqual,
            .lessEqual
        ]
    }
}
