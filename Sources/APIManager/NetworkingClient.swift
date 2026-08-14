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
    func send<T: Decodable, E: Endpoint>(
        request: URLRequest,
        for endpoint: E
    ) async throws -> T where E.EndpointError == Never {
        let (data, response) = try await URLSession.shared.data(for: request)
//        Debug.log("endpoint: \(endpoint)\n\nresponse: \(response)", category: .network)
        try response.checkForServerError()
        try response.checkAuthStatus()
        return try endpoint.jsonDecoder().decode(T.self, from: data)
    }
    
    func send<T: Decodable, E: Endpoint>(
        request: URLRequest,
        for endpoint: E
    ) async throws -> T where E.EndpointError: EndpointErrorType {
        let (data, response) = try await URLSession.shared.data(for: request)
//        Debug.log("endpoint: \(endpoint)\n\nresponse: \(response)", category: .network)
        try endpoint.parseError(from: response, with: data)
        try response.checkForServerError()
        try response.checkAuthStatus()
        return try endpoint.jsonDecoder().decode(T.self, from: data)
    }
}

