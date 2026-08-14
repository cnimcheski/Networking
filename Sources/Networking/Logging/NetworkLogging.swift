//
//  NetworkLogging.swift
//  Networking
//
//  Created by Steve Nimcheski on 8/14/26.
//

/// Logs a message for debugging or monitoring network activity.
public protocol NetworkLogging: Sendable {
    func log(_ message: @autoclosure () -> String)
}
