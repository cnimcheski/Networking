//
//  URLResponse+Extensions.swift
//  APIManager
//
//  Created by Steve Nimcheski on 8/13/26.
//

import Foundation

extension URLResponse {
    func checkForServerError() throws {
        guard let httpResponse = self as? HTTPURLResponse else { return }
        if (400..<600).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }
    }
    
    func checkAuthStatus() throws {
        guard let httpResponse = self as? HTTPURLResponse, httpResponse.statusCode == 401 else { return }
        throw URLError(.userAuthenticationRequired)
    }
}
