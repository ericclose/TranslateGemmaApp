import Foundation

public struct ModelInfo: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let size: String
    public var isDownloaded: Bool = false
    public var downloadProgress: Double = 0
    public var completedSize: Int64 = 0
    public var totalSize: Int64 = 0
    
    public init(id: String, name: String, size: String, isDownloaded: Bool = false, downloadProgress: Double = 0, completedSize: Int64 = 0, totalSize: Int64 = 0) {
        self.id = id
        self.name = name
        self.size = size
        self.isDownloaded = isDownloaded
        self.downloadProgress = downloadProgress
        self.completedSize = completedSize
        self.totalSize = totalSize
    }
}
