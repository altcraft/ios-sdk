//
//  StringBuilder.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Formats the function name by replacing any parameters with `()`.
///
/// Handles nested parentheses correctly by finding the first `(` and its
/// matching close paren via a balance counter, then replacing the entire
/// parameter span with `()`.
func formatFunctionName(_ functionName: String) -> String {
    guard let openIdx = functionName.firstIndex(of: "(") else {
        return functionName
    }

    var depth = 0
    var i = openIdx
    while i < functionName.endIndex {
        let ch = functionName[i]
        if ch == "(" { depth += 1 }
        else if ch == ")" {
            depth -= 1
            if depth == 0 { break }
        }
        i = functionName.index(after: i)
    }

    guard i < functionName.endIndex else {
        return functionName
    }

    let closeIdx = i
    return functionName[..<openIdx] + "()" + functionName[functionName.index(after: closeIdx)...]
}

/// Builds a JSON string from matching parameters.
///
/// The layout is byte-identical to the legacy implementation so existing
/// stored hashes remain valid; values are JSON-escaped before interpolation,
/// which the raw interpolation never did (a quote or backslash in a value
/// used to corrupt the JSON and change the resulting hash).
///
/// Key order is fixed by the template — do not switch to `JSONEncoder`,
/// whose dictionary-backed key order is non-deterministic across processes
/// and would make the derived hash unstable.
///
/// - Parameters:
///   - dbId: Database identifier.
///   - matching: Matching field name.
///   - value: Matching value.
/// - Returns: A JSON-formatted string with keys defined in `Constants.AuthKeys`
///            (`dbId`, `matching`, `matchingID`).
func matchingAsString(dbId: Int, matching: String, value: String) -> String {
    /// Escapes JSON string content: quotes, backslashes, and control scalars.
    func escaped(_ source: String) -> String {
        var output = ""
        for scalar in source.unicodeScalars {
            switch scalar {
            case "\"": output += "\\\""
            case "\\": output += "\\\\"
            case "\n": output += "\\n"
            case "\r": output += "\\r"
            case "\t": output += "\\t"
            default:
                if scalar.value < 0x20 {
                    output += String(format: "\\u%04x", scalar.value)
                } else {
                    output.unicodeScalars.append(scalar)
                }
            }
        }
        return output
    }

    return """
    {
      "\(Constants.AuthKeys.dbId)": "\(dbId)",
      "\(Constants.AuthKeys.matching)": "\(escaped(matching))",
      "\(Constants.AuthKeys.matchingID)": "\(escaped(value))"
    }
    """
}
