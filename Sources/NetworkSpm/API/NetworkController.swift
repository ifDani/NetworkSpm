//
//  File.swift
//  
//
//  Created by Daniel Carracedo  on 15/4/24.
//

import Foundation
import Combine

open class Network: NetworkProtocol {
    public var manager: NetworkController = NetworkController()

    public init() {}
}

public enum BodyType {
    case inBody
    case inQuery
}

public class NetworkController {
    private var debug = false
    public init() {}
    //  MARK: - Async Await
    public func request<T: Decodable>(_ method: HttpMethod,
                                      decoder: JSONDecoder = newJSONDecoder(),
                                      url: URL?,
                                      headers: [String: Any] = [String: Any](),
                                      params: [String: Any]? = nil,
                                      mustEncodeParams: Bool = false,
                                      bodyType: BodyType = .inBody) async throws -> T {
        let randomRequest = "\(Int.random(in: 0 ..< 100))"
        var timeDateRequest = Date()

        if debug {
            debugPrint("🌎🔵 [API][ASYNC] [id: \(randomRequest)] [URL]: [\(String(describing: url))]")
            print("🌎🔵 [API][ASYNC] [id: \(randomRequest)] [QUERY ITEMS]: [\(String(describing: params))]")
            print("🌎🔵 [API][ASYNC] [id: \(randomRequest)] [HEADER ITEMS]: [\(String(describing: headers))]")
        }

        guard let url = url else {
            if debug {
                debugPrint("🌎🔴 [API][ASYNC] [id: \(randomRequest)] [RESPONSE ERROR]: [invalidURL]")
            }
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch bodyType {
        case .inBody:
            if mustEncodeParams {
                urlRequest.httpBody = params?.paramsEncoded()
            } else {
                if let params {
                    urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])
                }
            }
        case .inQuery:
            urlRequest.url = buildURLWithQueryItems(url: url, params: params)
        }

        headers.forEach { (key, value) in
            if let value = value as? String {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        do {
            timeDateRequest = Date()

            if debug {
                debugPrint("🌎🔵 [API][ASYNC] [id: \(randomRequest)] [SUBSCRIPTION]")
            }

            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            if debug {
                debugPrint("🌎🔵 [API][ASYNC] [id: \(randomRequest)] [COMPLETION][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                print("🌎🔵 [API][ASYNC] [id: \(randomRequest)] [OUTPUT]: [\(data.printAsJSON())]")
            }

            guard let response = response as? HTTPURLResponse else {
                if debug {
                    debugPrint("🌎🔴 [API][ASYNC] [id: \(randomRequest)] [RESPONSE ERROR]: [noResponse]")
                }
                throw NetworkError.noResponse
            }

            if response.statusCode >= 200 && response.statusCode < 299 {
                if T.Type.self == EmptyResponse.Type.self {
                    if debug {
                        debugPrint("🌎🔵 [API][ASYNC] [id: \(randomRequest)] [PARSER]: [EmptyResponse]")
                    }
                    return EmptyResponse() as! T
                } else {
                    let value = try decoder.decode(T.self, from: data)
                    if debug {
                        debugPrint("🌎🔵 [API][ASYNC] [id: \(randomRequest)] [PARSER]: [OK]")
                    }
                    return value
                }
            } else {
                let errorValue = try decoder.decode(ErrorResponse.self, from: data)
                if debug {
                    debugPrint("🌎⚠️ [API][ASYNC] [id: \(randomRequest)] [ERROR RESPONSE]: [\(errorValue)]")
                }

                throw NetworkError.serverError(errorValue.errorMessage ?? "default.error.message")
            }
        } catch let DecodingError.dataCorrupted(context) {
            if debug {
                debugPrint("🌎🔴 [API][ASYNC] [id: \(randomRequest)] [CANCEL][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                debugPrint("🌎🔴 [API][ASYNC] [id: \(randomRequest)] [DECODING-ERROR] [dataCorrupted]: [\(context)]")
            }
            throw NetworkError.decode("decoding error")
        } catch let DecodingError.keyNotFound(key, context) {
            if debug {
                debugPrint("🌎🔴 [API] [id: \(randomRequest)] [CANCEL][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                debugPrint("🌎🔴 [API] [id: \(randomRequest)] [DECODING-ERROR] [keyNotFound]: [Key \(key) not found: \(context.debugDescription)]")
                debugPrint("🌎🔴 [API] [id: \(randomRequest)] [DECODING-ERROR] [keyNotFound]: [CodingPath: \(context.codingPath)]")
            }
            throw NetworkError.decode("decoding error")
        } catch let DecodingError.valueNotFound(value, context) {
            if debug {
                debugPrint("🌎🔴 [API] [id: \(randomRequest)] [CANCEL][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                debugPrint("🌎🔴 [API] [id: \(randomRequest)] [DECODING-ERROR] [valueNotFound]: [Value \(value) not found: \(context.debugDescription)]")
                debugPrint("🌎🔴 [API] [id: \(randomRequest)] [DECODING-ERROR] [valueNotFound]: [CodingPath: \(context.codingPath)]")
            }
            throw NetworkError.decode("decoding error")
        } catch let DecodingError.typeMismatch(type, context)  {
            if debug {
                debugPrint("🌎🔴 [API] [id: \(randomRequest)] [CANCEL][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                debugPrint("🌎🔴 [API] [id: \(randomRequest)] [DECODING-ERROR] [typeMismatch]: [Type \(type) mismatch: \(context.debugDescription)]")
                debugPrint("🌎🔴 [API] [id: \(randomRequest)] [DECODING-ERROR] [typeMismatch]: [CodingPath: \(context.codingPath)]")
            }
            throw NetworkError.decode("decoding error")
        } catch URLError.Code.notConnectedToInternet {
            if debug {
                debugPrint("🌎🔴 [API] [id: \(randomRequest)] [CANCEL][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                debugPrint("🌎🔴 [API] [id: \(randomRequest)] [NO INTERNET CONNECTION]")
            }
            throw NetworkError.noInternet("default.connection.error.message")
        } catch {
            if debug {
                debugPrint("🌎🔴 [API] [id: \(randomRequest)] [CANCEL][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                debugPrint("🌎🔴 [API] [id: \(randomRequest)] [ERROR]: [\(error)]")
            }
            throw error
        }
    }

    //  MARK: - Combine
    public func request<T: Decodable>(_ method : HttpMethod,
                                      decoder  : JSONDecoder = newJSONDecoder(),
                                      url      : URL,
                                      headers  : [String: Any] = [String : Any](),
                                      params   : [String: Any]? = nil) -> AnyPublisher<T, Error> {
        let randomRequest   = "\(Int.random(in: 0 ..< 100))"
        var timeDateRequest = Date()
        if debug {
            debugPrint("🌎🔵 [API][COMBINE] [id: \(randomRequest)] [URL]: [\(String(describing: url))]")
            print("🌎🔵 [API][COMBINE] [id: \(randomRequest)] [PARAMETERS]: [\(String(describing: params))]")
            print("🌎🔵 [API][COMBINE] [id: \(randomRequest)] [HEADER ITEMS]: [\(String(describing: headers))]")
        }

        var urlRequest        = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.httpBody   = params?.paramsEncoded()

        headers.forEach { (key, value) in
            if let value = value as? String {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        return URLSession.shared.dataTaskPublisher(for: urlRequest)
        //  MARK: - Combine Events
            .handleEvents(receiveSubscription: { subscription in
                timeDateRequest = Date()
                if self.debug {
                    debugPrint("🌎🔵 [API][COMBINE] [id: \(randomRequest)] [SUBSCRIPTION]")
                }
            }, receiveOutput: { value in
                if self.debug {
                    print("🌎🔵 [API][COMBINE] [id: \(randomRequest)] [OUTPUT]: [\(value.data.printAsJSON())]")
                }
            }, receiveCompletion: { value in
                if self.debug {
                    debugPrint("🌎🔵 [API][COMBINE] [id: \(randomRequest)] [COMPLETION][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                }
            }, receiveCancel: {
                if self.debug {
                    debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [CANCEL][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                }
            })
        //  MARK: - Map Error
            .mapError { error -> Error in
                if self.debug {
                    debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [ERROR]: [\(error.localizedDescription)]")
                }

                return error
            }
        //  MARK: - Map Response
            .tryMap { result in
                guard let response = result.response as? HTTPURLResponse else {
                    if self.debug {
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [RESPONSE ERROR]: [noResponse]")
                    }
                    throw NetworkError.noResponse
                }

                do {
                    timeDateRequest = Date()

                    if self.debug {
                        debugPrint("🌎🔵 [API][COMBINE] [id: \(randomRequest)] [OUTPUT]: [\(String(decoding: result.data, as: UTF8.self))]")
                    }

                    if response.statusCode >= 200 && response.statusCode < 299 {
                        if T.Type.self == EmptyResponse.Type.self {
                            if self.debug {
                                debugPrint("🌎🔵 [API][COMBINE] [id: \(randomRequest)] [PARSER]: [EmptyResponse]")
                            }
                            return EmptyResponse() as! T
                        } else {
                            let value = try decoder.decode(T.self, from: result.data)
                            if self.debug {
                                debugPrint("🌎🔵 [API][COMBINE] [id: \(randomRequest)] [PARSER]: [OK]")
                            }
                            return value
                        }
                    } else {
                        let errorValue = try decoder.decode(ErrorResponse.self, from: result.data)
                        if self.debug {
                            debugPrint("🌎⚠️ [API][COMBINE] [id: \(randomRequest)] [ERROR RESPONSE]: [\(errorValue)]")
                        }

                        throw NetworkError.serverError(errorValue.errorMessage ?? "default.error.message")
                    }
                } catch let DecodingError.dataCorrupted(context) {
                    if self.debug {
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [CANCEL][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [DECODING-ERROR] [dataCorrupted]: [\(context)]")
                    }
                    throw NetworkError.decode("decoding error")
                } catch let DecodingError.keyNotFound(key, context) {
                    if self.debug {
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [CANCEL][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [DECODING-ERROR] [keyNotFound]: [Key \(key) not found: \(context.debugDescription)]")
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [DECODING-ERROR] [keyNotFound]: [CodingPath: \(context.codingPath)]")
                    }
                    throw NetworkError.decode("decoding error")
                } catch let DecodingError.valueNotFound(value, context) {
                    if self.debug {
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [CANCEL][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [DECODING-ERROR] [valueNotFound]: [Value \(value) not found: \(context.debugDescription)]")
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [DECODING-ERROR] [valueNotFound]: [CodingPath: \(context.codingPath)]")
                    }
                    throw NetworkError.decode("decoding error")
                } catch let DecodingError.typeMismatch(type, context)  {
                    if self.debug {
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [CANCEL][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [DECODING-ERROR] [typeMismatch]: [Type \(type) mismatch: \(context.debugDescription)]")
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [DECODING-ERROR] [typeMismatch]: [CodingPath: \(context.codingPath)]")
                    }
                    throw NetworkError.decode("decoding error")
                } catch URLError.Code.notConnectedToInternet {
                    if self.debug {
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [CANCEL][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [NO INTERNET CONNECTION]")
                    }
                    throw NetworkError.noInternet("default.connection.error.message")
                } catch {
                    if self.debug {
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [CANCEL][TIME]: [\(Date().timeIntervalSince(timeDateRequest).milliseconds)ms]")
                        debugPrint("🌎🔴 [API][COMBINE] [id: \(randomRequest)] [ERROR]: [\(error)]")
                    }
                    throw error
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

extension NetworkController {
    public static func _printChanges() -> NetworkController {
        let controller = NetworkController()
        controller.debug = true
        return controller
    }

    private func buildURLWithQueryItems(url: URL, params: [String: Any]?) -> URL {
        guard let params = params else {
            return url
        }

        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = params.queryItems
        return urlComponents?.url ?? url
    }
}
