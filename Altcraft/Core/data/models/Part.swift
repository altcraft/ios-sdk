//
//  Part.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Represents a single multipart form-data section.
/// Used to build HTTP multipart requests.
///
/// Each `Part` contains metadata and raw data for upload.
///
/// - Parameters:
///   - name: Field name in the multipart form.
///   - data: Binary data content.
///   - mime: MIME type (e.g. `"text/plain"`, `"application/json"`).
///   - filename: Optional filename for file uploads.
struct Part {
    let name: String
    let data: Data
    let mime: String
    let filename: String?

    init(
        name: String,
        data: Data,
        mime: String,
        filename: String?
    ) {
        self.name = name
        self.data = data
        self.mime = mime
        self.filename = filename
    }
}
