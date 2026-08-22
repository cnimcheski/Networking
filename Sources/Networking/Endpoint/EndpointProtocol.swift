//
//  EndpointProtocol.swift
//  climbto350
//
//  Created by Steve Nimcheski on 7/11/25.
//

import Foundation

public protocol Endpoint {
    associatedtype EndpointError = Never
    var path: String { get }
    var queryParameters: [String: String] { get }
    var body: Encodable? { get }
    var rawBody: Data? { get }
    var method: HTTPMethod { get }
    var dateDecodingFormat: DateFormat? { get }
    var requiresAuth: Bool { get }
    var shouldHandleGlobalErrors: Bool { get }
}

// MARK: - Default Implementations

public extension Endpoint {
    var rawBody: Data? { nil }
    var shouldHandleGlobalErrors: Bool { true }
    
    func urlRequest(using baseURL: URL?) throws -> URLRequest {
        guard let fullURL = baseURL?.appendingPath(path, query: queryParameters) else { throw URLError(.badURL) }
        var request = URLRequest(url: fullURL)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        } else if let rawBody {
            request.httpBody = rawBody
        }
        return request
    }
    
    func jsonDecoder() throws -> JSONDecoder {
        let decoder = JSONDecoder()
        if let dateDecodingFormat {
            let formatter = DateFormatter()
            formatter.dateFormat = dateDecodingFormat.rawValue
            decoder.dateDecodingStrategy = .formatted(formatter)
        }
        return decoder
    }
}

// MARK: - APIError Conformance

extension Endpoint where EndpointError: APIError {
    func parseError(from urlResponse: URLResponse, with data: Data) throws {
        guard let httpResponse = urlResponse as? HTTPURLResponse else { return }
        for error in EndpointError.allCases {
            guard error.statusCode == httpResponse.statusCode else { continue }
            guard let errorMessage = error.message else { throw error }
            guard let responseMessage = try? JSONDecoder().decode(DetailResponse.self, from: data).detail else { throw URLError(.badServerResponse) }
            if errorMessage == responseMessage { throw error }
        }
    }
}
