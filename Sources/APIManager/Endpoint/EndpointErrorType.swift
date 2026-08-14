//
//  EndpointErrorType.swift
//  climbto350
//
//  Created by Steve Nimcheski on 7/20/25.
//

public protocol EndpointErrorType: Error, CaseIterable {
    var statusCode: Int { get }
    var message: String? { get }
}
