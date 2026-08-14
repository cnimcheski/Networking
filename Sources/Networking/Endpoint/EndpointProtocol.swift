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
    var baseURL: URL { get }
    var body: Encodable? { get }
    var method: HTTPMethod { get }
    var dateDecodingFormat: DateFormat? { get }
    var requiresAuth: Bool { get }
    var shouldHandleGlobalErrors: Bool { get }
}

// MARK: - Private Default Implementations

private extension Endpoint {
    var fullURL: URL? {
        baseURL.appendingPath(path, query: queryParameters)
    }
}

// MARK: - Public Default Implementations

public extension Endpoint {
    var shouldHandleGlobalErrors: Bool { true }
    
    func urlRequest() throws -> URLRequest {
        guard let fullURL else { throw URLError(.badURL) }
        var request = URLRequest(url: fullURL)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
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

// MARK: - EndpointErrorType Conformance

extension Endpoint where EndpointError: EndpointErrorType {
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
