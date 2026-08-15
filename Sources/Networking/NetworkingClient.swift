//
//  NetworkingClient.swift
//  APIManager
//
//  Created by Steve Nimcheski on 8/13/26.
//

import Foundation

/// Makes the raw network calls and handles all global and endpoint specific errors by passing them up to the caller
/// Throws authentication errors up to the caller as well
public final class NetworkingClient {
    private let errorHandler: any APIErrorHandling
    private let logger: any NetworkLogging
    
    public init(errorHandler: any APIErrorHandling, logger: any NetworkLogging) {
        self.errorHandler = errorHandler
        self.logger = logger
    }
    
    public func send<T: Decodable, E: Endpoint>(
        request: URLRequest,
        for endpoint: E
    ) async throws -> T where E.EndpointError == Never {
        let (data, response) = try await URLSession.shared.data(for: request)
        logger.log("endpoint: \(endpoint)\n\nresponse: \(response)")
        try errorHandler.parseError(from: response, with: data)
        try response.checkForServerError()
        try response.checkAuthStatus()
        return try endpoint.jsonDecoder().decode(T.self, from: data)
    }
    
    public func send<T: Decodable, E: Endpoint>(
        request: URLRequest,
        for endpoint: E
    ) async throws -> T where E.EndpointError: APIError {
        let (data, response) = try await URLSession.shared.data(for: request)
        logger.log("endpoint: \(endpoint)\n\nresponse: \(response)")
        try errorHandler.parseError(from: response, with: data)
        try endpoint.parseError(from: response, with: data)
        try response.checkForServerError()
        try response.checkAuthStatus()
        return try endpoint.jsonDecoder().decode(T.self, from: data)
    }
}

