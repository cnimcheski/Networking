// The Swift Programming Language
// https://docs.swift.org/swift-book

import Combine
import Foundation

public enum DateFormat: String {
    case full = "y-MM-dd'T'HH:mm:ss"
    case date = "yyyy-MM-dd"
}

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

public final class APIManager<APIGlobalError: APIError> {
    private let baseURL: URL?
    private let networkingClient: NetworkingClient
    private let errorHandler: any APIErrorHandling<APIGlobalError>
    private let authenticator: any APIAuthenticator
    private let logger: any NetworkLogging
    
    private let unauthenticatedSubject = PassthroughSubject<Void, Never>()
    
    public var unauthenticatedPublisher: AnyPublisher<Void, Never> {
        unauthenticatedSubject.eraseToAnyPublisher()
    }
    
    public init(
        baseURL: URL?,
        networkingClient: NetworkingClient,
        errorHandler: any APIErrorHandling<APIGlobalError>,
        authenticator: any APIAuthenticator,
        logger: any NetworkLogging
    ) {
        self.baseURL = baseURL
        self.networkingClient = networkingClient
        self.errorHandler = errorHandler
        self.authenticator = authenticator
        self.logger = logger
    }
    
    public func performRequest<T: Decodable, E: Endpoint>(for endpoint: E) async -> T? where E.EndpointError == Never {
        do {
            return try await makeRequest(for: endpoint)
        } catch URLError.userAuthenticationRequired {
            await handleAuthorizationError()
        } catch is APIGlobalError {
            /// APIGlobalError's that weren't successfully retried are silently ignored.
        } catch URLError.notConnectedToInternet {
            /// Connection errors that weren't successfully retried are silently ignored.
        } catch is CancellationError, URLError.cancelled {
            /// Cancellation errors are silently ignored
        } catch {
            /// Server errors that weren't successfully retried are silently ignored.
        }
        return nil
    }
    
    public func performRequest<T: Decodable, E: Endpoint>(for endpoint: E) async throws(E.EndpointError) -> T? where E.EndpointError: APIError {
        do {
            return try await makeRequest(for: endpoint)
        } catch URLError.userAuthenticationRequired {
            await handleAuthorizationError()
            //        } catch URLError.notConnectedToInternet {
            //            await handleConnectionError(for: endpoint)
        } catch is APIGlobalError {
            /// APIGlobalError's that weren't successfully retried are silently ignored.
        } catch URLError.notConnectedToInternet {
            /// Connection errors that weren't successfully retried are silently ignored.
        } catch let error as E.EndpointError {
            throw error
        } catch is CancellationError, URLError.cancelled {
            /// Cancellation errors are silently ignored.
        } catch {
            /// Server errors that weren't successfully retried are silently ignored.
        }
        return nil
    }
}

// MARK: - Private makeRequest Methods

private extension APIManager {
    func makeRequest<T: Decodable, E: Endpoint>(
        for endpoint: E,
        allowRetry: Bool = true
    ) async throws -> T where E.EndpointError == Never {
        let request = try await buildRequest(for: endpoint)
        do {
            return try await networkingClient.send(request: request, for: endpoint)
        } catch let error as APIGlobalError {
            return try await handleAPIError(error, for: endpoint)
        } catch URLError.notConnectedToInternet {
            return try await handleConnectionError(for: endpoint)
        } catch URLError.userAuthenticationRequired {
            if allowRetry {
                try await authenticator.refreshAccessToken()
                return try await makeRequest(for: endpoint, allowRetry: false)
            }
            throw URLError(.userAuthenticationRequired)
        } catch let error as DecodingError {
            logger.log("endpoint: \(endpoint)\n\ndecoding error")
            throw error
        } catch {
            return try await handleServerError(error, for: endpoint)
        }
    }
    
    func makeRequest<T: Decodable, E: Endpoint>(
        for endpoint: E,
        allowRetry: Bool = true
    ) async throws -> T where E.EndpointError: APIError {
        let request = try await buildRequest(for: endpoint)
        do {
            return try await networkingClient.send(request: request, for: endpoint)
        } catch let error as APIGlobalError {
            return try await handleAPIError(error, for: endpoint)
        } catch URLError.notConnectedToInternet {
            return try await handleConnectionError(for: endpoint)
        } catch let error as E.EndpointError {
            throw error
        } catch URLError.userAuthenticationRequired {
            if allowRetry {
                try await authenticator.refreshAccessToken()
                return try await makeRequest(for: endpoint, allowRetry: false)
            }
            throw URLError(.userAuthenticationRequired)
        } catch let error as DecodingError {
            logger.log("endpoint: \(endpoint)\n\ndecoding error")
            throw error
        } catch {
            return try await handleServerError(error, for: endpoint)
        }
    }
}

// MARK: - Authorization Error Handling

private extension APIManager {
    func handleAuthorizationError() async {
        unauthenticatedSubject.send()
    }
}

// MARK: - Global Error Handling

private extension APIManager {
    func handleAPIError<E: Endpoint, T: Decodable>(
        _ error: APIGlobalError,
        for endpoint: E
    ) async throws -> T where E.EndpointError == Never {
        guard endpoint.shouldHandleGlobalErrors else { throw error }
        guard let response: T = try await errorHandler.handleAPIGlobalError(
            error,
            retry: {
                try await self.makeRequest(for: endpoint, allowRetry: false)
            }
        ) else { throw error }
        return response
    }
    
    func handleAPIError<E: Endpoint, T: Decodable>(
        _ error: APIGlobalError,
        for endpoint: E
    ) async throws -> T where E.EndpointError: APIError {
        guard endpoint.shouldHandleGlobalErrors else { throw error }
        guard let response: T = try await errorHandler.handleAPIGlobalError(
            error,
            retry: {
                try await self.makeRequest(for: endpoint, allowRetry: false)
            }
        ) else { throw error }
        return response
    }
}

// MARK: - Connection Error Handling

private extension APIManager {
    func handleConnectionError<E: Endpoint, T: Decodable>(
        for endpoint: E
    ) async throws -> T where E.EndpointError ==  Never {
        guard endpoint.shouldHandleGlobalErrors else { throw URLError(.notConnectedToInternet) }
        guard let response: T = try await errorHandler.handleGlobalConnectionError(
            retry: {
                try await self.makeRequest(for: endpoint, allowRetry: false)
            }
        ) else { throw URLError(.notConnectedToInternet) }
        return response
    }
    
    func handleConnectionError<E: Endpoint, T: Decodable>(
        for endpoint: E
    ) async throws -> T where E.EndpointError: APIError {
        guard endpoint.shouldHandleGlobalErrors else { throw URLError(.notConnectedToInternet) }
        guard let response: T = try await errorHandler.handleGlobalConnectionError(
            retry: {
                try await self.makeRequest(for: endpoint, allowRetry: false)
            }
        ) else { throw URLError(.notConnectedToInternet) }
        return response
    }
}

// MARK: - Server Error Handling

private extension APIManager {
    func handleServerError<E: Endpoint, T: Decodable>(
        _ error: Error,
        for endpoint: E
    ) async throws -> T where E.EndpointError == Never {
        guard endpoint.shouldHandleGlobalErrors else { throw error }
        guard let response: T = try await errorHandler.handleGlobalServerError(
            retry: {
                try await self.makeRequest(for: endpoint, allowRetry: false)
            }
        ) else { throw error }
        return response
    }
    
    func handleServerError<E: Endpoint, T: Decodable>(
        _ error: Error,
        for endpoint: E
    ) async throws -> T where E.EndpointError: APIError {
        guard endpoint.shouldHandleGlobalErrors else { throw error }
        guard let response: T = try await errorHandler.handleGlobalServerError(
            retry: {
                try await self.makeRequest(for: endpoint, allowRetry: false)
            }
        ) else { throw error }
        return response
    }
}

// MARK: - Private Helpers

private extension APIManager {
    func buildRequest<E: Endpoint>(for endpoint: E) async throws -> URLRequest {
        var request = try endpoint.urlRequest(using: baseURL)
        if endpoint.requiresAuth {
            try await addAuthorization(to: &request)
        }
        return request
    }
    
    func addAuthorization(to request: inout URLRequest) async throws {
        let accessToken = try await authenticator.getAccessToken()
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
}
