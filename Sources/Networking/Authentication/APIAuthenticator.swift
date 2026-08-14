//
//  APIAuthenticator.swift
//  APIManager
//
//  Created by Steve Nimcheski on 8/13/26.
//

public protocol APIAuthenticator: Sendable {
    /// Fetches and returns the current valid accessToken.
    func getAccessToken() async throws -> String
    
    /// Fetches a new accessToken using a refreshToken.
    /// Must update the value of the accessToken so the APIManager can use the updated value.
    func refreshAccessToken() async throws
}
