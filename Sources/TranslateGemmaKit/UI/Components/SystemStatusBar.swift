import SwiftUI

public struct SystemStatusBar: View {
    @Environment(SystemMonitor.self) private var systemMonitor
    
    public init() {}
    
    private func formatBytes(_ bytes: Double) -> String {
        let gb = bytes / (1024 * 1024 * 1024)
        return String(format: "%.1f GB", gb)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) { // Reduced spacing
            StatusRow(
                icon: "cpu",
                label: "CPU",
                value: systemMonitor.cpuUsage,
                color: .blue
            )
            
            StatusRow(
                icon: "memorychip",
                label: "MEM",
                value: systemMonitor.ramTotal > 0 ? systemMonitor.ramUsed / systemMonitor.ramTotal : 0,
                color: .purple,
                subDetail: "\(formatBytes(systemMonitor.ramUsed)) / \(formatBytes(systemMonitor.ramTotal))"
            )
            
            StatusRow(
                icon: "square.stack.3d.up",
                label: "GPU",
                value: systemMonitor.gpuUsage,
                color: .teal
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 230) // Shrunk from 260
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct StatusRow: View {
    let icon: String
    let label: String
    let value: Double
    let color: Color
    var subDetail: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) { // Reduced spacing
            HStack(alignment: .center, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 8, weight: .bold)) // Shrunk icon
                        .foregroundColor(color.opacity(0.9))
                        .frame(width: 10)
                    
                    Text(label)
                        .font(.system(size: 9, weight: .bold, design: .rounded)) // Shrunk font
                        .foregroundColor(.secondary)
                }
                .frame(width: 40, alignment: .leading)
                
                Spacer()
                
                if let subDetail = subDetail {
                    Text(subDetail)
                        .font(.system(size: 8, weight: .medium, design: .monospaced)) // Shrunk font
                        .foregroundColor(.secondary.opacity(0.8))
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                Spacer()
                
                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 9, weight: .bold, design: .monospaced)) // Shrunk font
                    .foregroundColor(.primary)
                    .frame(width: 30, alignment: .trailing)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.1), lineWidth: 0.5)
                        )
                        .frame(height: 2.5) // Shrunk bar height
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(value))), height: 2.5)
                        .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 0)
                }
            }
            .frame(height: 2.5)
        }
    }
}
