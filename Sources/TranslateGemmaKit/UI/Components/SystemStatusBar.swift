import SwiftUI

public struct SystemStatusBar: View {
    @Environment(SystemMonitor.self) private var systemMonitor
    
    public init() {}
    
    private func formatBytes(_ bytes: Double) -> String {
        let gb = bytes / (1024 * 1024 * 1024)
        return String(format: "%.1fG", gb)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                subDetail: "\(formatBytes(systemMonitor.ramUsed))/\(formatBytes(systemMonitor.ramTotal))"
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
        .frame(width: 200) // Reduced from 280
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 0.5)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color.opacity(0.8))
                    .frame(width: 12)
                
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let subDetail = subDetail {
                    Text(subDetail)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.trailing, 4)
                }
                
                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.9))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Improved background visibility with a subtle stroke
                    Capsule()
                        .fill(.white.opacity(0.08))
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.05), lineWidth: 0.5)
                        )
                        .frame(height: 3)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(value))), height: 3)
                        .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 0)
                }
            }
            .frame(height: 3)
        }
    }
}
