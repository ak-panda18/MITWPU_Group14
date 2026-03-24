import Foundation

struct StoredDoc: Codable, Equatable {
    var id: String
    var title: String
    var createdDate: Date
    var fileName: String
    var thumbnailFileName: String
    var ocrTextFileName: String?
    var pagesFileName: String?
    
    var dateText: String {
        return DateFormatter.localizedString(from: createdDate, dateStyle: .medium, timeStyle: .none)
    }
    
    // MARK: - Standard Init
    init(id: String, title: String, createdDate: Date, fileName: String, thumbnailFileName: String, ocrTextFileName: String?, pagesFileName: String?) {
        self.id = id
        self.title = title
        self.createdDate = createdDate
        self.fileName = fileName
        self.thumbnailFileName = thumbnailFileName
        self.ocrTextFileName = ocrTextFileName
        self.pagesFileName = pagesFileName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        fileName = try container.decode(String.self, forKey: .fileName)
        thumbnailFileName = try container.decode(String.self, forKey: .thumbnailFileName)
        ocrTextFileName = try container.decodeIfPresent(String.self, forKey: .ocrTextFileName)
        pagesFileName = try container.decodeIfPresent(String.self, forKey: .pagesFileName)
        
        if let date = try? container.decode(Date.self, forKey: .createdDate) {
            createdDate = date
        } else {
            createdDate = Date()
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, createdDate, fileName, thumbnailFileName, ocrTextFileName, pagesFileName
    }
}
