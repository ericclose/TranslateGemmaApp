import Foundation
import Hub

// Mocking AppConfiguration logic
let home = FileManager.default.homeDirectoryForCurrentUser
let hubPath = home.appendingPathComponent(".cache/huggingface/hub")
let hub = HubApi(downloadBase: hubPath)

let modelId = "mlx-community/translategemma-4b-it-4bit"
let repo = Hub.Repo(id: modelId)
let path = hub.localRepoLocation(repo)

print("Model ID: \(modelId)")
print("Hub Path: \(hubPath.path)")
print("Local Repo Location: \(path.path)")
