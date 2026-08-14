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

public final class APIManager {
    private let networkingClient: NetworkingClient
    private let errorHandler: any ErrorHandling
    private let authenticator: any APIAuthenticator
    
    private let unauthenticatedSubject = PassthroughSubject<Void, Never>()
    
    public var unauthenticatedPublisher: AnyPublisher<Void, Never> {
        unauthenticatedSubject.eraseToAnyPublisher()
    }
    
    public init(
        networkingClient: NetworkingClient,
        errorHandler: any ErrorHandling,
        authenticator: any APIAuthenticator
    ) {
        self.networkingClient = networkingClient
        self.errorHandler = errorHandler
        self.authenticator = authenticator
    }
    
    func performRequest<T: Decodable, E: Endpoint>(for endpoint: E) async -> T? where E.EndpointError == Never {
        do {
            return try await makeRequest(for: endpoint)
        } catch URLError.userAuthenticationRequired {
            await handleAuthorizationError()
        } catch URLError.notConnectedToInternet {
            await errorHandler.handleGlobalConnectionError(for: endpoint)
        } catch is CancellationError, URLError.cancelled {
            /// Cancellation errors are silently ignored
        } catch {
            await errorHandler.handleGlobalServerError(for: endpoint)
        }
        return nil
    }
    
    func performRequest<T: Decodable, E: Endpoint>(for endpoint: E) async throws(E.EndpointError) -> T? where E.EndpointError: EndpointErrorType {
        do {
            return try await makeRequest(for: endpoint)
        } catch URLError.userAuthenticationRequired {
            await handleAuthorizationError()
        } catch URLError.notConnectedToInternet {
            await errorHandler.handleGlobalConnectionError(for: endpoint)
        } catch let error as E.EndpointError {
            throw error
        } catch is CancellationError, URLError.cancelled {
            /// Cancellation errors are silently ignored
        } catch {
            await errorHandler.handleGlobalServerError(for: endpoint)
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
        } catch URLError.userAuthenticationRequired {
            if allowRetry {
                try await authenticator.refreshAccessToken()
                return try await makeRequest(for: endpoint, allowRetry: false)
            }
            throw URLError(.userAuthenticationRequired)
        } catch let error as DecodingError {
//            Debug.log("endpoint: \(endpoint)\n\ndecoding error", category: .network)
            throw error
        } catch {
            throw error
        }
    }
    
    func makeRequest<T: Decodable, E: Endpoint>(
        for endpoint: E,
        allowRetry: Bool = true
    ) async throws -> T where E.EndpointError: EndpointErrorType {
        let request = try await buildRequest(for: endpoint)
        do {
            return try await networkingClient.send(request: request, for: endpoint)
        } catch URLError.userAuthenticationRequired {
            if allowRetry {
                try await authenticator.refreshAccessToken()
                return try await makeRequest(for: endpoint, allowRetry: false)
            }
            throw URLError(.userAuthenticationRequired)
        } catch let error as DecodingError {
//            Debug.log("endpoint: \(endpoint)\n\ndecoding error", category: .network)
            throw error
        } catch {
            throw error
        }
    }
}

// MARK: - Error Handling

private extension APIManager {
    func handleAuthorizationError() async {
        unauthenticatedSubject.send()
    }
}

// MARK: - Private Helpers

private extension APIManager {
    func buildRequest<E: Endpoint>(for endpoint: E) async throws -> URLRequest {
        var request = try endpoint.urlRequest()
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
