//
//  MultipartBody.swift
//  Altcraft
//
//  Created by andrey on 07.10.2025.
//

import Foundation

/// Generates a unique multipart boundary string.
@inline(__always)
func makeBoundary() -> String {
    "Boundary-\(UUID().uuidString)"
}

/// Builds the `Content-Disposition` header for a multipart part.
/// - Parameters:
///   - name: Form field name.
///   - filename: Optional file name.
/// - Returns: Header data for the part.
@inline(__always) private func contentDisposition(_ name: String, filename: String?) -> Data {
    if let filename, !filename.isEmpty {
        return Data("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".utf8)
    } else {
        return Data("Content-Disposition: form-data; name=\"\(name)\"\r\n".utf8)
    }
}

/// Builds a complete multipart/form-data body.
/// - Parameters:
///   - parts: Array of form-data parts.
///   - boundary: Multipart boundary string.
/// - Returns: Encoded multipart body as `Data`.
@inline(__always)
func buildMultipartBody(parts: [Part], boundary: String) -> Data {
    var body = Data()
    let lineBreak = "\r\n"
    let boundaryPrefix = "--\(boundary)\r\n"

    for p in parts {
        body.append(Data(boundaryPrefix.utf8))
        body.append(contentDisposition(p.name, filename: p.filename))
        body.append(Data("Content-Type: \(p.mime)\r\n\r\n".utf8))
        body.append(p.data)
        body.append(Data(lineBreak.utf8))
    }

    body.append(Data("--\(boundary)--\r\n".utf8))
    return body
}
