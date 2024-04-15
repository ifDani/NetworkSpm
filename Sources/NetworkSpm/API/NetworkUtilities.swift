//
//  File.swift
//  
//
//  Created by Daniel Carracedo  on 15/4/24.
//

import Foundation

//  MARK: - JSON Decoder
public func newJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
        decoder.dateDecodingStrategy = .iso8601
    }
    return decoder
}

//  MARK: - Extension TimeInterval
extension TimeInterval {
    var milliseconds: Int {
        return Int(self * 1_000)
    }
}

//  MARK: - Extension Dictionary
extension Dictionary {
    func paramsEncoded() -> Data? {
        return map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}

extension Dictionary where Key == String, Value == Any {
    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        for (key, value) in self {
            let stringValue: String
            if let arrayValue = value as? [Any] {
                stringValue = arrayValue.compactMap { String(describing: $0) }.joined(separator: ",")
            } else {
                stringValue = String(describing: value)
            }
            let queryItem = URLQueryItem(name: key, value: stringValue)
            items.append(queryItem)
        }
        return items
    }
}

extension Data {
    func printAsJSON() -> String {
        guard let jsonData = try? JSONSerialization.jsonObject(with: self, options: []) else { return "" }
        guard let json = try? JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted) else { return "" }
        guard let jsonString = String(data: json, encoding: .utf8) else { return "" }
        return jsonString
    }
}
