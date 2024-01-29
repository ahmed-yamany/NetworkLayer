//  APIRequest.swift
//  iCinema
//
//  Created by Ahmed Yamany on 13/03/2023.
//
import Foundation
import Alamofire
import Combine
 
@available(iOS 13.0, *)
open class APIRequest<DecodableType: Decodable, BackendErrorType: BackendError> {
    
    public private(set) var url: String
    public private(set) var method: HTTPMethod
    public private(set) var query: Parameters = [:]
    public private(set) var body: Parameters?
    public private(set) var headers: HTTPHeaders = [:]
    
    var cancellableSet: Set<AnyCancellable> = []
    
    public init(url: String, method: HTTPMethod) {
        self.url = url
        self.method = method
    }
    
    public func request() -> AnyPublisher<DecodableType, Error> {
        AF.request(
            url,
            method: method,
            parameters: getParameters(),
            encoding: getEncoding(),
            headers: headers
        )
        .validate() /// 1: Validates that the response has a status code in the default acceptable range of 200...299
        .publishDecodable(type: DecodableType.self)
        .handleBackendErrors(ofType: BackendErrorType.self)
    }
    
    public func request(onSuccess: @escaping (DecodableType) -> Void, onError: @escaping (Error) -> Void) {
        self.request()
            .sink(receiveCompletion: { completion in
                switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        onError(error)
                }
            }, receiveValue: { value in
                onSuccess(value)
            })
            .store(in: &cancellableSet)
    }
    
    public func request() async throws -> DecodableType {
        try await withCheckedThrowingContinuation { continuation in
            self.request(onSuccess: { value in
                continuation.resume(with: .success(value))
            }, onError: { error in
                continuation.resume(throwing: error)
            })
        }
    }
    
    public func cancelAllRequests() {
        self.cancellableSet.forEach { $0.cancel() }
        self.cancellableSet.removeAll()
    }
    
    public func update(query: Parameters) {
        query.forEach { self.query[$0] = $1 }
    }
    
    public func update(headers: [String: String]) {
        headers.forEach { self.headers.update(name: $0, value: $1) }
    }
    
    public func update(body: Parameters) {
        if self.body == nil {
            self.body = [:]
        }
        body.forEach { self.body?.updateValue($1, forKey: $0) }
    }
    
    private func getParameters() -> Parameters {
        guard let body else {
            return query
        }
        
        return body
    }
    
    private func getEncoding() -> ParameterEncoding {
        guard let body else {
            return URLEncoding.queryString
        }
        
        return URLEncoding.httpBody
    }
}
