//
//  APIError.swift
//  climbto350
//
//  Created by Steve Nimcheski on 7/20/25.
//

/// An error returned by an API, identified by an HTTP status code and optional message.
public protocol APIError: Error, CaseIterable {
    var statusCode: Int { get }
    var message: String? { get }
}
