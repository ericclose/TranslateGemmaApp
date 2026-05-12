import SwiftUI

public struct SystemStatusBar: View {
    @Environment(SystemMonitor.self) private var systemMonitor
    
    public init() {}
    
    private func formatBytes(_ bytes: Double) -> String {
        let gb = bytes / (1024 * 1024 * 1024)
        return String(format: "%.1f GB", gb)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatusRow(
                label: "CPU usage",
                value: systemMonitor.cpuUsage,
                detail: "",
                color: .blue
            )
            
            StatusRow(
                label: "Memory usage",
                value: systemMonitor.ramTotal > 0 ? systemMonitor.ramUsed / systemMonitor.ramTotal : 0,
                detail: "",
                color: .purple,
                subDetail: "\(formatBytes(systemMonitor.ramUsed)) / \(formatBytes(systemMonitor.ramTotal))"
            )
            
            StatusRow(
                label: "GPU utilisation",
                value: systemMonitor.gpuUsage,
                detail: "",
                color: .teal
            )
        }
        .padding(16)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct StatusRow: View {
    let label: String
    let value: Double
    let detail: String
    let color: Color
    var subDetail: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    if let subDetail = subDetail {
                        Text(subDetail)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(width: 40, alignment: .trailing)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.05))
                        .frame(height: 4)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(value))), height: 4)
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 4)
        }
    }
}
