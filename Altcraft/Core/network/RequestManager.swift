//
//  RequestManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Sends HTTP requests and preserves required headers during redirects.
@_spi(_Altcraft) public final class RequestManager: NSObject, @unchecked Sendable {
    /// Shared request manager instance.
    public static let shared = RequestManager()

    /// URL session configured with redirect handling.
    ///
    /// Access is synchronized with a lock: Swift `lazy var` initialization is
    /// not thread-safe, and `sendRequest` may be called concurrently from
    /// multiple tasks. The session is created exactly once.
    private var session: URLSession {
        sessionLock.lock()
        defer { sessionLock.unlock() }

        if let session = sessionStorage {
            return session
        }

        let configuration = URLSessionConfiguration.default
        let created = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )
        sessionStorage = created
        return created
    }

    /// Guard for the lazy session initialization.
    private let sessionLock = NSLock()

    /// Created session storage; `nil` until the first request.
    private var sessionStorage: URLSession?

    /// Sends a typed HTTP request and returns a processed API response.
    ///
    /// - Parameters:
    ///   - request: URL request to execute.
    ///   - requestData: Request metadata with response type and SDK events.
    /// - Returns: Parsed response body, HTTP code, and generated SDK event.
    public func sendRequest<T: RequestModel.RequestData>(
        request: URLRequest,
        requestData: T
    ) async -> ResponseProcessor.ApiResponse<T.Response> {
        let functionName = requestData.moduleLogPrefix + "\(#function): \(requestData.requestName)"

        do {
            guard SerialCommandQueue.isCurrent() else { throw CancellationError() }
            let (data, response) = try await session.dataAsync(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return ResponseProcessor.ApiResponse(
                    httpCode: nil,
                    response: nil,
                    event: retryEvent(
                        functionName,
                        error: CoreEvents.invalidResponseFormat
                    )
                )
            }

            return ResponseProcessor.processResponse(
                request: requestData,
                response: httpResponse,
                data: data
            )
        } catch {
            return ResponseProcessor.ApiResponse(
                httpCode: nil,
                response: nil,
                event: retryEvent(functionName, error: error)
            )
        }
    }
}

/// Response processing utilities shared by ``RequestManager``.
///
/// Module-facing surface: ``ApiResponse`` returned by
/// ``RequestManager/sendRequest(request:requestData:)``.
@_spi(_Altcraft) public enum ResponseProcessor {
    /// Result category based on HTTP status code.
    enum ResponseStatus {
        case success
        case retry
        case error
    }

    /// Processed API response.
    ///
    /// - Properties:
    ///   - httpCode: HTTP status code returned by the server.
    ///   - response: Parsed response body, or `nil` if unavailable.
    ///   - event: SDK event generated from the response result.
    public struct ApiResponse<T: ResponseModel.ResponseData> {
        public let httpCode: Int?
        public let response: T?
        public let event: Event

        public init(
            httpCode: Int?,
            response: T?,
            event: Event
        ) {
            self.httpCode = httpCode
            self.response = response
            self.event = event
        }
    }

    /// JSON decoder used for typed response parsing.
    private static let decoder = JSONDecoder()

    /// Parses raw response data into the expected response model.
    ///
    /// - Parameters:
    ///   - data: Raw response body.
    ///   - request: Request metadata with expected response type.
    /// - Returns: Parsed response model, or `nil` if decoding fails.
    private static func parseResponse<T: RequestModel.RequestData>(
        data: Data?,
        request: T
    ) -> T.Response? {
        guard let data, !data.isEmpty else {
            return nil
        }

        // Mirrors Android `Response.parseResponse`: gateway/HTML bodies
        // (e.g. a 502 page returned while retrying) are not API payloads —
        // skip them silently instead of logging a decode error on every
        // retry attempt.
        guard let body = String(data: data, encoding: .utf8), body.isJsonString else {
            return nil
        }

        do {
            return try decoder.decode(request.responseType, from: data)
        } catch {
            _ = CoreLog.error("parseResponse", error: error)
            return nil
        }
    }

    /// Maps an HTTP status code to a response status.
    ///
    /// - Parameter code: HTTP status code.
    /// - Returns: Response status used for event generation.
    private static func responseStatus(code: Int?) -> ResponseStatus {
        guard let code else {
            return .error
        }

        switch code {
        case 200...299, 304:
            return .success
        case 500...599:
            return .retry
        default:
            return .error
        }
    }

    /// Builds processed response data with SDK event context.
    ///
    /// - Parameters:
    ///   - response: HTTP response metadata.
    ///   - data: Raw response body.
    ///   - request: Request metadata with events and response type.
    /// - Returns: Response result used for final API response creation.
    private static func getResponseData<T: RequestModel.RequestData>(
        response: HTTPURLResponse,
        data: Data?,
        request: T
    ) -> ResponseModel.ResponseResult<T.Response> {
        let parsedBody = parseResponse(data: data, request: request)

        let value = MapBuilder.createEventValue(
            code: response.statusCode,
            response: parsedBody,
            request: request
        )

        return ResponseModel.ResponseResult(
            status: responseStatus(code: response.statusCode),
            responseData: parsedBody,
            httpCode: response.statusCode,
            value: value,
            errorEvent: request.failedEvent,
            successEvent: request.successEvent
        )
    }

    /// Generates an SDK event from processed response data.
    ///
    /// - Parameters:
    ///   - result: Processed response data with event context.
    ///   - moduleLogPrefix: Module prefix (e.g. `"[altcraft-inapp] "`) supplied by the
    ///     request's `RequestData.moduleLogPrefix` so the resulting event is tagged
    ///     with the module that issued the request (mirrors Android `processResponse`).
    /// - Returns: Success, retry, or error SDK event.
    private static func eventGeneration<T: ResponseModel.ResponseData>(
        result: ResponseModel.ResponseResult<T>,
        moduleLogPrefix: String
    ) -> Event {
        let functionName = moduleLogPrefix + "processResponse"

        switch result.status {
        case .success:
            return emitEvent(
                functionName,
                event: result.successEvent,
                eventValue: result.value.eventValue,
                logValue: result.value.logValue
            )

        case .retry:
            return retryEvent(
                functionName,
                error: result.errorEvent,
                eventValue: result.value.eventValue,
                logValue: result.value.logValue
            )

        case .error:
            return errorEvent(
                functionName,
                error: result.errorEvent,
                eventValue: result.value.eventValue,
                logValue: result.value.logValue
            )
        }
    }

    /// Processes an HTTP response into parsed body, code, and SDK event.
    ///
    /// - Parameters:
    ///   - request: Request metadata with response type and SDK events.
    ///   - response: HTTP response metadata.
    ///   - data: Raw response body.
    /// - Returns: Final API response.
    static func processResponse<T: RequestModel.RequestData>(
        request: T,
        response: HTTPURLResponse,
        data: Data?
    ) -> ApiResponse<T.Response> {
        let result = getResponseData(
            response: response,
            data: data,
            request: request
        )

        return ApiResponse(
            httpCode: result.httpCode,
            response: result.responseData,
            event: eventGeneration(result: result, moduleLogPrefix: request.moduleLogPrefix)
        )
    }
}

extension RequestManager: URLSessionTaskDelegate {

    /// Handles redirects and copies required headers to the redirected request.
    ///
    /// - Parameters:
    ///   - session: URL session handling the task.
    ///   - task: Task that received the redirect response.
    ///   - response: Redirect HTTP response.
    ///   - request: New redirect request.
    ///   - completionHandler: Completion handler receiving the modified request.
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var redirectedRequest = request

        if let originalRequest = task.originalRequest {
            [
                Constants.HTTPHeader.authorization,
                Constants.HTTPHeader.requestId,
                Constants.HTTPHeader.contentType
            ].forEach { header in
                if let value = originalRequest.value(forHTTPHeaderField: header) {
                    redirectedRequest.setValue(value, forHTTPHeaderField: header)
                }
            }
        }

        completionHandler(redirectedRequest)
    }
}

// MARK: - Unit Test Hooks

extension RequestManager {

    /// Test hook returning the runtime identity of the shared URL session.
    ///
    /// Concurrent calls must return the same identifier, proving the session
    /// is created exactly once.
    ///
    /// - Returns: `ObjectIdentifier` of the session.
    func test_sessionIdentifier() -> ObjectIdentifier {
        ObjectIdentifier(session)
    }
}

extension URLSession {

    /// Executes a URL request using async/await.
    ///
    /// - Parameter request: URL request to execute.
    /// - Returns: Response data and URL response.
    /// - Throws: Transport error or bad server response error.
    public func dataAsync(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            guard SerialCommandQueue.isCurrent() else {
                continuation.resume(throwing: CancellationError())
                return
            }
            let task = self.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }

                continuation.resume(returning: (data ?? Data(), response))
            }

            // Serialize the actual network start with queue invalidation.
            if !SerialCommandQueue.performIfCurrent({ task.resume() }) {
                task.cancel()
            }
        }
    }
}
