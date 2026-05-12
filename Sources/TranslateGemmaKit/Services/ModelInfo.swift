import Foundation

public struct ModelInfo: Identifiable, Hashable {
    public let id: String
    public var name: String
    public var size: String
    public var isDownloaded: Bool
    public var downloadProgress: Double = 0
    public var completedSize: Int64 = 0
    public var totalSize: Int64 = 0
    
    public init(id: String, name: String, size: String, isDownloaded: Bool) {
        self.id = id
        self.name = name
        self.size = size
        self.isDownloaded = isDownloaded
    }
}
