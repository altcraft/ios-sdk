//
//  Extension.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

extension Data {
    
    /// Initializes a `Data` instance by decoding a Base64URL-encoded string.
    ///
    /// This is commonly used for decoding JWT payloads where Base64URL encoding is used
    /// instead of standard Base64. The method replaces `-` and `_` with standard Base64
    /// characters and adds padding if necessary.
    ///
    /// - Parameter string: A Base64URL-encoded string.
    /// - Returns: `nil` if the string cannot be decoded into `Data`.
    init?(base64UrlEncoded string: String) {
        var base64String = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        while base64String.count % 4 != 0 {
            base64String.append("=")
        }

        guard let data = Data(base64Encoded: base64String) else {
            return nil
        }
        self = data
    }
}


// One shared queue for all such lists.
private let _tsListQueue = DispatchQueue(label: "com.altcraft.tslist", attributes: .concurrent)

extension Array where Element == String? {

    /// Thread-safe append (stores `nil` too).
    /// - Parameter value: Element to append.
    public mutating func ts_append(_ value: Element) {
        _tsListQueue.sync(flags: .barrier) {
            self.append(value)
        }
    }

    /// Thread-safe removal of all elements.
    /// - Parameter keepingCapacity: Pass `true` to keep the existing capacity.
    public mutating func ts_removeAll(keepingCapacity: Bool = false) {
        _tsListQueue.sync(flags: .barrier) {
            self.removeAll(keepingCapacity: keepingCapacity)
        }
    }

    /// Thread-safe retrieval of the last element.
    /// - Returns: The last element or `nil` if the list is empty.
    public func ts_last() -> Element? {
        _tsListQueue.sync { self.last }
    }
}
