//
//  File.swift
//  
//
//  Created by Ahmed Yamany on 29/01/2024.
//

import Combine
import Alamofire
import Foundation

/// Represents an error type that combines conformance to Error, Codable, and LocalizedError.
public typealias BackendError =  Error & Codable & LocalizedError

@available(iOS 13, *)
public extension DataResponsePublisher {
    /// Maps and handles errors in a way that is specifically tailored for backend errors.
    ///
    /// - Parameters:
    ///   - errorType: The type of backend error to handle. It must conform to BackendError.
    /// - Returns: A publisher that emits a value if successful or an error if there's a failure.
    func handleBackendErrors<ErrorType: BackendError>(ofType errorType: ErrorType.Type) -> AnyPublisher<Value, Error>  {
        self.map { response ->  DataResponse<Value, Error> in
            response.mapError { error -> Error in
                // try to decode data to The errorType
                if let backendError = response.data.flatMap({ try? JSONDecoder().decode(errorType.self, from: $0)}) {
                    return backendError
                }
                return error
            }
        }
        .receive(on: DispatchQueue.main)
        .tryMap { response -> Value in
            // Try mapping the response, throwing the error if present, or returning the value.
            if let error = response.error {
                throw error
            }
            return response.value! // if there is no error then the value is always available
        }
        .eraseToAnyPublisher()
    }
}
