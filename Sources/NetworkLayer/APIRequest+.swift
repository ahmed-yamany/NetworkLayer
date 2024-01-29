//
//  File.swift
//  
//
//  Created by Ahmed Yamany on 06/09/2023.
//

import Foundation
import Alamofire
import Combine

public enum FilesTypes: String, CaseIterable {
    case file
    case image
    case video
}

public struct MultiPartType {
    let fileType: FilesTypes
    let fileExtension: String
    let data: Data
}

@available(iOS 13.0, *)
extension APIRequest {
    public func request(multiPart: [String: MultiPartType]) -> AnyPublisher<DecodableType, Error> {
        AF.upload(multipartFormData: { self.update($0, with: multiPart) },
                  to: url,
                   method: method,
                   headers: headers )
        .validate()
        .publishDecodable(type: DecodableType.self)
        .handleBackendErrors(ofType: BackendErrorType.self)
    }
 
    private func update(_ multiPartFormData: MultipartFormData, with multiPart: [String: MultiPartType]) {
        multiPart.forEach { key, value in   /// Iterate over each key-value pair in the dictionary
            let uniqueIdForFile = UUID().uuidString
            
            let fileName = "\(uniqueIdForFile).\(value.fileExtension)"
            let mimeType = "\(value.fileType.rawValue)/\(value.fileExtension)"
            
            /// Add the file to the multipart form data
            multiPartFormData.append(value.data, withName: key, fileName: fileName, mimeType: mimeType)
        }
        
        // Update the multipart form data with any additional parameters
        self.update(multiPartFormData, with: self.query)
    }
  
    private func update(_ multiPartFormData: MultipartFormData, with parameters: Parameters) {
        for (key, value) in parameters {    /// Loop over each key-value pair in the `parameters` dictionary.
            /// If the value is an array, append each element to the form data with the same key name.
            if let value = value as? NSArray {
                let keyObj = key + "[]"
                for element in value {
                    self.append(element, to: keyObj, in: multiPartFormData)
                }
            }
            
            /// Otherwise, append the single value to the form data with the given key name.
            else {
                self.append(value, to: key, in: multiPartFormData)
            }
        }
    }

    private func append(_ value: Any, to key: String, in multiPartFormData: MultipartFormData) {
        guard let data = "\(value)".data(using: .utf8) else { return }
        multiPartFormData.append(data, withName: key)
    }
}
