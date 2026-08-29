//
//  APIManagerError.swift
//  Networking
//
//  Created by Steve Nimcheski on 8/28/26.
//

/// Defines all the errors the API Manager can throw.
public enum APIManagerError<APIGlobalError: APIError>: Error {
    case cancellation
    case custom(APIGlobalError)
    case endpoint(any APIError)
    case network
    case server
    case unauthorized
}
