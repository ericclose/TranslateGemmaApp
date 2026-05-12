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
                icon: "cpu",
                label: "CPU",
                value: systemMonitor.cpuUsage,
                color: .blue
            )
            
            StatusRow(
                icon: "memorychip",
                label: "Mem",
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 220) // Slightly wider for centered text
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.95)) // Reduced transparency
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

struct StatusRow: View {
    let icon: String
    let label: String
    let value: Double
    let color: Color
    var subDetail: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color.opacity(0.9))
                    .frame(width: 12)
                
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let subDetail = subDetail {
                    Text(subDetail)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Spacer() // Push to middle
                }
                
                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Much clearer background for the bar
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.1), lineWidth: 0.5)
                        )
                        .frame(height: 3.5)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(value))), height: 3.5)
                        .shadow(color: color.opacity(0.4), radius: 2, x: 0, y: 0)
                }
            }
            .frame(height: 3.5)
        }
    }
}
