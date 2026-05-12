import Foundation
import SwiftUI
import IOKit
import Darwin
import Observation

@Observable
public class SystemMonitor {
    public var cpuUsage: Double = 0
    public var ramUsed: Double = 0
    public var ramTotal: Double = 0
    public var gpuUsage: Double = 0
    
    private var timer: Timer?
    private var previousCpuLoadInfo = host_cpu_load_info()
    
    public init() {
        fetchRamTotal()
        startMonitoring()
    }
    
    public func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
        updateStats()
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateStats() {
        updateCpuUsage()
        updateRamUsage()
        updateGpuUsage()
    }
    
    private func fetchRamTotal() {
        var stats = host_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_info(mach_host_self(), HOST_BASIC_INFO, $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            self.ramTotal = Double(stats.max_mem)
        }
    }
    
    private func updateCpuUsage() {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        var cpuLoadInfo = host_cpu_load_info()
        
        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        
        if result == KERN_SUCCESS {
            let userDiff = Double(cpuLoadInfo.cpu_ticks.0 &- previousCpuLoadInfo.cpu_ticks.0)
            let sysDiff  = Double(cpuLoadInfo.cpu_ticks.1 &- previousCpuLoadInfo.cpu_ticks.1)
            let idleDiff = Double(cpuLoadInfo.cpu_ticks.2 &- previousCpuLoadInfo.cpu_ticks.2)
            let niceDiff = Double(cpuLoadInfo.cpu_ticks.3 &- previousCpuLoadInfo.cpu_ticks.3)
            
            let totalTicks = sysDiff + userDiff + niceDiff + idleDiff
            if totalTicks > 0 {
                let usage = (sysDiff + userDiff + niceDiff) / totalTicks
                self.cpuUsage = usage
            }
            
            self.previousCpuLoadInfo = cpuLoadInfo
        }
    }
    
    private func updateRamUsage() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = Double(vm_page_size)
            let active = Double(stats.active_count) * pageSize
            let speculative = Double(stats.speculative_count) * pageSize
            let inactive = Double(stats.inactive_count) * pageSize
            let wired = Double(stats.wire_count) * pageSize
            let compressed = Double(stats.compressor_page_count) * pageSize
            let purgeable = Double(stats.purgeable_count) * pageSize
            let external = Double(stats.external_page_count) * pageSize
            
            // Used RAM logic from stats: active + inactive + speculative + wired + compressed - purgeable - external
            let used = active + inactive + speculative + wired + compressed - purgeable - external
            self.ramUsed = used
        }
    }
    
    private func updateGpuUsage() {
        let entry = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOAccelerator"))
        if entry != 0 {
            defer { IOObjectRelease(entry) }
            var props: Unmanaged<CFMutableDictionary>?
            let result = IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0)
            if result == kIOReturnSuccess, let dict = props?.takeRetainedValue() as? [String: Any] {
                if let stats = dict["PerformanceStatistics"] as? [String: Any] {
                    let utilization = stats["Device Utilization %"] as? Int ?? stats["GPU Activity(%)"] as? Int
                    if let val = utilization {
                        self.gpuUsage = Double(min(100, max(0, val))) / 100.0
                    }
                }
            }
        }
    }
}
