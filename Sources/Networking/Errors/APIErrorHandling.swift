//
//  APIErrorHandling.swift
//  APIManager
//
//  Created by Steve Nimcheski on 8/13/26.
//

/// Allows apps to provide an action for how global API errors (Internet/Server) should be handled.
/// Ex: Toasts or Alerts.
public protocol APIErrorHandling: Sendable {
    @MainActor func handleGlobalConnectionError<E: Endpoint>(for endpoint: E) async
    @MainActor func handleGlobalServerError<E: Endpoint>(for endpoint: E) async
}
