//
//  APIErrorHandling.swift
//  APIManager
//
//  Created by Steve Nimcheski on 8/13/26.
//

import Foundation

/// Allows apps to provide an action for how global API errors should be handled.
/// Ex: Toasts or Alerts.
public nonisolated protocol APIErrorHandling<APIGlobalError> {
    associatedtype APIGlobalError: APIError
    
    /// Handles an API-level error and optionally retries the failed request.
    ///
    /// Conforming types can use this method to provide custom handling for each API-level error. The retry closure
    /// can be invoked to re-execute the original request when appropriate.
    ///
    /// - Parameters:
    ///   - error: The `APIGlobalError` type so that conforming types can run an action for each different error.
    ///   - retry: A closure that re-executes the failed API request. Can be ignored if not needed.
    /// - Returns: The response from a successful retry, or `nil` if the error was handled without producing a response.
    func handleAPIGlobalError<T>(
        _ error: APIGlobalError,
        retry: @escaping () async throws -> T
    ) async throws -> T?
    
    /// Handles a connection error and optionally retries the failed request.
    ///  
    /// The retry closure can be invoked to re-execute the original request when appropriate.
    ///  
    /// - Parameter retry: A closure that re-executes the failed API request. Can be ignored if not needed.
    /// - Returns: The response from a successful retry, or `nil` if the error was handled without producing a response.
    func handleGlobalConnectionError<T>(
        retry: @escaping () async throws -> T
    ) async throws -> T?
    
    /// Handles a server error (any 400 to 599 status code error) and optionally retries the failed request.
    ///
    /// The retry closure can be invoked to re-execute the original request when appropriate.
    ///
    /// - Parameter retry: A closure that re-executes the failed API request. Can be ignored if not needed.
    /// - Returns: The response from a successful retry, or `nil` if the error was handled without producing a response.
    func handleGlobalServerError<T>(
        retry: @escaping () async throws -> T
    ) async throws -> T?
}

// MARK: - APIError Conformance

extension APIErrorHandling {
    func parseError(from urlResponse: URLResponse, with data: Data) throws {
        guard let httpResponse = urlResponse as? HTTPURLResponse else { return }
        for error in APIGlobalError.allCases {
            guard error.statusCode == httpResponse.statusCode else { continue }
            guard let errorMessage = error.message else { throw error }
            guard let responseMessage = try? JSONDecoder().decode(DetailResponse.self, from: data).detail else { throw URLError(.badServerResponse) }
            if errorMessage == responseMessage { throw error }
        }
    }
}
