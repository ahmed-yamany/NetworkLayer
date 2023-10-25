//
//  File.swift
//  
//
//  Created by Ahmed Yamany on 06/09/2023.
//

import Foundation
import Alamofire
import Combine

/**
 An extension of the `APIRequest` protocol that adds support for making multipart API requests using Alamofire and Combine.
 */
@available(iOS 13.0, *)
extension APIRequest {
    /**
    Initiates a multipart API request and returns a publisher for the response.

    - Parameter multiPart: A dictionary containing the multipart data to be included in the request.
    - Returns: A publisher for the multipart API request response wrapped in a `DataResponse`.
    */
    public func request(multiPart: [String: MultiPartType]) -> AnyPublisher<DecodableType, Error> {
        let request = AF.upload( multipartFormData: { self.update($0, with: multiPart) },
                                 to: self.url,
                                 method: networkRequest.method,
                                 headers: networkRequest.headers )
            .validate()
            .publishDecodable(type: DecodableType.self)
        return mapError(with: request)
    }
    /**
      Updates the `MultipartFormData` with the specified multipart data.
      
      - Parameter multiPartFormData: The `MultipartFormData` object to update.
      - Parameter multiPart: A dictionary containing the multipart data to be included in the request.
      */
    private func update(_ multiPartFormData: MultipartFormData, with multiPart: [String: MultiPartType]) {
        // Iterate over each key-value pair in the dictionary
        multiPart.forEach { key, value in
            // Generate a unique ID for the file
//            let uuid = "\((arc4random_uniform(99999)) + (arc4random_uniform(99999)))"
            let uuid = UUID().uuidString
            // Construct the file name and MIME type for the file
            let fileName = "\(uuid).\(value.extention)"
            let mimeType = "\(value.type.rawValue)/\(value.extention)"
            // Add the file to the multipart form data
            multiPartFormData.append(value.data, withName: key, fileName: fileName, mimeType: mimeType)
        }
        // Update the multipart form data with any additional parameters
        self.update(multiPartFormData, with: self.networkRequest.parameters)
    }
    /**
    Updates the `MultipartFormData` with additional parameters.

    - Parameter multiPartFormData: The `MultipartFormData` object to update.
    - Parameter parameters: A dictionary containing additional parameters to be included in the request.
    */
    private func update(_ multiPartFormData: MultipartFormData, with parameters: Parameters) {
        // Loop over each key-value pair in the `parameters` dictionary.
        for (key, value) in parameters {
            // If the value is an array, append each element to the form data with the same key name.
            if let value = value as? NSArray {
                let keyObj = key + "[]"
                for element in value {
                    self.append(element, to: keyObj, in: multiPartFormData)
                }
            }
            // Otherwise, append the single value to the form data with the given key name.
            else {
                self.append(value, to: key, in: multiPartFormData)
            }
        }
    }
    /**
    Appends a value to the `MultipartFormData` with the specified key.

    - Parameter value: The value to be appended.
    - Parameter key: The key under which the value should be appended.
    - Parameter multiPartFormData: The `MultipartFormData` object to which the value is appended.
    */
    private func append(_ value: Any, to key: String, in multiPartFormData: MultipartFormData) {
        guard let data = "\(value)".data(using: .utf8) else { return }
        multiPartFormData.append(data, withName: key)
    }
}
