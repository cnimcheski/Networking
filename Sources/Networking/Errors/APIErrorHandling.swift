//
//  APIErrorHandling.swift
//  APIManager
//
//  Created by Steve Nimcheski on 8/13/26.
//

import Foundation

/// Allows apps to provide an action for how global API errors (Internet/Server) should be handled.
/// Ex: Toasts or Alerts.
public protocol APIErrorHandling<APIGlobalError>: Sendable {
    associatedtype APIGlobalError: APIError = Never
    @MainActor func handleAPIGlobalError(_ error: APIGlobalError)
    @MainActor func handleGlobalConnectionError() async
    @MainActor func handleGlobalServerError() async
}

// MARK: - Default Implementation

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
