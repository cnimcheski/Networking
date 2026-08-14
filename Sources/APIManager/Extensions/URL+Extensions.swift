//
//  URL+Extensions.swift
//  APIManager
//
//  Created by Steve Nimcheski on 8/13/26.
//

import Foundation

extension URL {
    func appendingPath(_ path: String, query: [String: String] = [:]) -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.path += path
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components?.url
    }
}
