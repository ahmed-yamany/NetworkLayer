//  APIRequest.swift
//  iCinema
//
//  Created by Ahmed Yamany on 13/03/2023.
//
import Foundation
import Alamofire
import Combine

@available(iOS 13.0, *)
public protocol APIRequest {
    /// The associated type representing the expected response type (must conform to Codable).
    associatedtype DecodableType where DecodableType: Codable
    associatedtype BackendErrorType where BackendErrorType: Codable & Error
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
    internal func mapError(with dataResponse: DataResponsePublisher<DecodableType>
        ) -> Publishers.Map<DataResponsePublisher<DecodableType>, DataResponse<DecodableType, Error>> {
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
    }
}

@available(iOS 13.0, *)
extension APIRequest {
    /**
    Initiates an API request and returns a publisher for the response.

    - Returns: A publisher for the API request response wrapped in a `DataResponse`.
    */
    public func request() -> AnyPublisher<DataResponse<DecodableType, Error>, Never> {
        // 0
        let request = AF.request(url, method: networkRequest.method,
                                 parameters: networkRequest.parameters,
                                 encoding: URLEncoding.queryString,
                                 headers: networkRequest.headers )
                        .validate() // 1
                        .publishDecodable(type: DecodableType.self) // 2
        return mapError(with: request) // 3
                .receive(on: DispatchQueue.main) // 4
                .eraseToAnyPublisher() // 5
    }
}
@available(iOS 13.0, *)
extension APIRequest {
    /**
    Initiates an API request and handles the response using a completion closure.

    - Parameter completion: A closure to handle the API response.
    */
    public mutating func request(_ completion: @escaping (DataResponse<DecodableType, Error>) -> Void) {
        self.request().sink { response in
            completion(response)
        }.store(in: &cancellableSet)
    }
    /**
    Cancels all active API request publishers in the `cancellableSet`.
    */
    public mutating func cancelAllPublishers() {
        self.cancellableSet.forEach { $0.cancel() }
        self.cancellableSet.removeAll()
    }
}
