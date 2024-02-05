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

public enum FilesExtension: String, CaseIterable {
    case png = ".png"
    case jpg = ".jpg"
    case jpeg = ".jpeg"
    case mp4 = ".mp4"
    case mp3 = ".mp3"
    case mkv = ".mkv"
    case txt = ".txt"
}

public struct MultiPartType {
    public let fileType: FilesTypes
    public let fileExtension: FilesExtension
    public let data: Data
    
    public init(fileType: FilesTypes, fileExtension: FilesExtension, data: Data) {
        self.fileType = fileType
        self.fileExtension = fileExtension
        self.data = data
    }
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
    
    public func request(
        multiPart: [String: MultiPartType],
        onSuccess: @escaping (DecodableType) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.request(multiPart: multiPart)
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
    
    public func request(multiPart: [String: MultiPartType]) async throws -> DecodableType {
        try await withCheckedThrowingContinuation { continuation in
            self.request(multiPart: multiPart, onSuccess: { value in
                continuation.resume(with: .success(value))
            }, onError: { error in
                continuation.resume(throwing: error)
            })
        }
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
