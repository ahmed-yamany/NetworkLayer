//  APIRequest.swift
//  iCinema
//
//  Created by Ahmed Yamany on 13/03/2023.
//
import Foundation
import Alamofire
import Combine

public protocol BackendErrorMessage: Error, Codable {
    var localizedDescription: String { get }
}
struct BackEnd: BackendErrorMessage {
    let localizedDescription: String
}
@available(iOS 13.0, *)
public protocol APIRequest {
    /// The associated type representing the expected response type (must conform to Codable).
    associatedtype DecodableType where DecodableType: Codable
    associatedtype BackendErrorType where BackendErrorType: BackendErrorMessage
    /// The network request configuration for the API request.
    var networkRequest: NetworkRequest { get }
    /// A set of cancellable objects to manage the API request's lifecycle.
    var cancellableSet: Set<AnyCancellable> { get set }
}

@available(iOS 13.0, *)
extension APIRequest {
    /**
     The URL for the API request by combining the host and endpoint from the `networkRequest`.
    */
    public var url: String { "\(networkRequest.host)\(networkRequest.endpoint)" }
    /**
     Maps errors from a `DataResponsePublisher` to a `DataResponse` with the appropriate error type.
     
     - Parameter dataResponse: The publisher to map errors from.
     - Returns: A publisher that maps errors to `NetworkError` and wraps the response.
     */
    internal func mapError(with dataResponse: DataResponsePublisher<DecodableType>) -> AnyPublisher<DecodableType, Error> {
        return dataResponse.map { response in
            response.mapError { error in
                let networkError: Error
                if let backendError = response.data.flatMap({ try? JSONDecoder().decode(BackendErrorType.self, from: $0)}) {
                    networkError = backendError
                } else {
                    networkError = error
                }
                return networkError
            }
        }
        .receive(on: DispatchQueue.main) // 4
        .tryMap { response -> Self.DecodableType in
            if let error = response.error {
                throw error
            }
            // swiftlint: disable all
            return response.value!
            // swiftlint: enable all
        }
        .eraseToAnyPublisher() // 5
    }
}

@available(iOS 13.0, *)
extension APIRequest {
    /**
    Initiates an API request and returns a publisher for the response.

    - Returns: A publisher for the API request response wrapped in a `DataResponse`.
    */
    public func request() -> AnyPublisher<DecodableType, Error> {
        let dataRequest: DataRequest
        if let body = self.networkRequest.body {
            dataRequest = AF.request(url, method: networkRequest.method,
                                     parameters: body,
                                     encoding: URLEncoding.httpBody,
                                     headers: networkRequest.headers )
        } else {
            dataRequest = AF.request(url, method: networkRequest.method,
                                     parameters: networkRequest.parameters,
                                     encoding: URLEncoding.queryString,
                                     headers: networkRequest.headers )
        }
        // 0
        let request = dataRequest
            .validate() // 1
            .publishDecodable(type: DecodableType.self) // 2
        return mapError(with: request) // 3
    }
}
@available(iOS 13.0, *)
extension APIRequest {
    /**
    Initiates an API request and handles the response using a completion closure.

    - Parameter completion: A closure to handle the API response.
    */
    public mutating func request(onSuccess: @escaping (Self.DecodableType) -> Void,
                                 onError: @escaping (BackendErrorMessage) -> Void) {
        self.request()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    if let error = error as? BackendErrorMessage {
                        onError(error)
                    } else {
                        onError(BackEnd(localizedDescription: error.localizedDescription))
                    }
                }
            }, receiveValue: { value in
                onSuccess(value)
            })
            .store(in: &cancellableSet)

    }
    /**
    Cancels all active API request publishers in the `cancellableSet`.
    */
    public mutating func cancelAllPublishers() {
        self.cancellableSet.forEach { $0.cancel() }
        self.cancellableSet.removeAll()
    }
}
