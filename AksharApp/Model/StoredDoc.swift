//
//  StroedDoc.swift
//  Akshar_V1
//
//  Created by Akshita Panda on 16/12/25.
//
import Foundation

struct StoredDoc: Codable, Equatable {
    var id: String
    var title: String
    var dateText: String
    var fileName: String
    var thumbnailFileName: String
    var ocrTextFileName: String?
    var pagesFileName: String?
}

