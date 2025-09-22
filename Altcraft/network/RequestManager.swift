//
//  NetworkManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// A singleton class responsible for sending HTTP requests
/// and handling redirects with header preservation.
final class RequestManager: NSObject {
    
    /// The shared singleton instance of `NetworkManager`.
    static let shared = RequestManager()
    
    /// A lazily-initialized URLSession with `NetworkManager` as its delegate.
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    /// Sends an HTTP request and handles response, error, or redirection.
    ///
    /// Automatically processes the response using `responseProcessing(...)` and ensures
    /// retry events are triggered on failure or invalid responses.
    ///
    /// - Parameters:
    ///   - request: The `URLRequest` to send.
    ///   - function: The name of the calling function (used for logging and event tagging).
    ///   - completion: A closure called with the resulting `Event` after the request completes.
    func sendRequest(
        request: URLRequest,
        requestName: String,
        uid: String? = nil,
        type: String? = nil,
        completion: @escaping (Event) -> Void
    ) {
        let functionName = "\(#function): \(requestName)"
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(retryEvent(functionName, error: error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(retryEvent(functionName, error: invalidResponseFormat))
                return
            }
            completion(
                self.responseProcessing(
                    response: httpResponse, data: data, requestName: requestName, uid: uid, type: type
                )
            )
        }.resume()
    }
    
    /// Processes a synchronous subscription response.
    /// - Parameters:
    ///   - response: The HTTP response from the request.
    ///   - data: The response data.
    /// - Returns: An `Event` representing the result.
    func responseProcessing(
        response: HTTPURLResponse,
        data: Data?,
        requestName: String,
        uid: String? = nil,
        type: String? = nil
    ) -> Event {
        let data = parseResponse(data: data)
     
        let successPair = createSuccessPair(requestName: requestName, type: type)
        
        let errorPair = createErrorPair(
            requestName: requestName, code: response.statusCode, response: data, type: type
        )
        
        let value = mapValue(code: response.statusCode, response: data, uid: uid, type: type)

        switch response.statusCode {
        case 200...299:
            return event(#function, event: successPair, value: value)
        case 500...599:
            return retryEvent(#function, error: errorPair, value: value)
        default:
            return errorEvent(#function, error: errorPair, value: value)
        }
    }
}

/// Handles HTTP redirection by preserving specific headers from the original request.
///
/// This method is called when a server response indicates a redirect (e.g., HTTP 3xx).
/// It copies selected headers (Authorization, Request-ID, Content-Type) from the original
/// request to the new redirected request before it is sent.
///
/// - Parameters:
///   - session: The session containing the task that will perform the redirection.
///   - task: The task whose request resulted in a redirect response.
///   - response: The response that triggered the redirection.
///   - request: The new request to be sent.
///   - completionHandler: A closure that receives the modified request to continue with, or `nil` to cancel the redirect.
extension RequestManager: URLSessionTaskDelegate {
    func urlSession(
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
