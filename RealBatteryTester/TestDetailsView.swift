import SwiftUI
import Foundation

struct TestDetailsView: View {
    let startTime: Date?
    let duration: TimeInterval
    let workload: Workload?
    let initialBatteryLevel: Double
    let currentBatteryLevel: Double
    let dropPerMinute: Double
    let initialEstimatedEnd: Date?
    let currentEstimatedEnd: Date?
    let initialEstimatedDuration: TimeInterval
    let extrapolatedFullTime: TimeInterval
    let isActive: Bool
    let showExtrapolated: Bool
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
    private func LabelWithTooltip(_ text: String, tooltip: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
                .help(tooltip)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    LabelWithTooltip("Test Start Time:", tooltip: "The exact time when the battery test was initiated")
                    Spacer()
                    if let startTime = startTime {
                        Text(dateFormatter.string(from: startTime))
                    } else {
                        Text("-")
                    }
                }
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.blue)
                    LabelWithTooltip("Test Duration:", tooltip: "How long the test has been running")
                    Spacer()
                    Text(formatTimeWithSeconds(duration))
                }
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.blue)
                    LabelWithTooltip("Workload Type:", tooltip: "The type of battery stress test being performed")
                    Spacer()
                    if let workload = workload {
                        Text(workload.description)
                    } else {
                        Text("-")
                    }
                }
            }
            
            Divider()
            
            Group {
                HStack {
                    Image(systemName: "battery.100")
                        .foregroundColor(.green)
                    LabelWithTooltip("Starting Battery Level:", tooltip: "Battery percentage when the test started")
                    Spacer()
                    Text(isActive ? "\(Int(initialBatteryLevel * 100))%" : "-")
                }
                HStack {
                    Image(systemName: "battery.75")
                        .foregroundColor(.green)
                    LabelWithTooltip("Current Battery Level:", tooltip: "Current battery percentage")
                    Spacer()
                    Text(isActive ? "\(Int(currentBatteryLevel * 100))%" : "-")
                }
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.orange)
                    LabelWithTooltip("Battery Drop:", tooltip: "Total percentage of battery used during this test")
                    Spacer()
                    Text(isActive ? String(format: "%.1f%%", (initialBatteryLevel - currentBatteryLevel) * 100) : "-")
                }
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundColor(.orange)
                    LabelWithTooltip("Battery Drain Rate:", tooltip: "How fast the battery is draining (percentage per minute)")
                    Spacer()
                    Text(isActive ? String(format: "%.2f%%/min", dropPerMinute) : "-")
                }
            }
            
            Divider()
            
            Group {
                HStack {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundColor(.purple)
                    LabelWithTooltip("Initial System Estimate:", tooltip: "When macOS initially estimated the battery would run out")
                    Spacer()
                    if let endTime = initialEstimatedEnd {
                        Text(dateFormatter.string(from: endTime))
                    } else {
                        Text("-")
                    }
                }
                HStack {
                    Image(systemName: "clock.badge")
                        .foregroundColor(.purple)
                    LabelWithTooltip("Current End Estimate:", tooltip: "When the battery will run out based on actual drain rate")
                    Spacer()
                    if let endTime = currentEstimatedEnd {
                        Text(dateFormatter.string(from: endTime))
                    } else {
                        Text("-")
                    }
                }
                HStack {
                    Image(systemName: "timer.circle")
                        .foregroundColor(.purple)
                    LabelWithTooltip("Initial Duration Estimate:", tooltip: "How long macOS initially estimated the battery would last")
                    Spacer()
                    Text(isActive ? formatTimeWithSeconds(initialEstimatedDuration) : "-")
                }
                HStack {
                    Image(systemName: "timer.circle.fill")
                        .foregroundColor(.purple)
                    LabelWithTooltip("Current Duration Estimate:", tooltip: "How long the battery will last based on actual drain rate")
                    Spacer()
                    if let endTime = currentEstimatedEnd, let startTime = startTime {
                        Text(formatTimeWithSeconds(endTime.timeIntervalSince(startTime)))
                    } else {
                        Text("-")
                    }
                }
            }
            
            Divider()
            
            Group {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                    LabelWithTooltip("Extrapolated Full Battery Time:", 
                        tooltip: "Estimated time to drain battery from 100% to 0% at current workload\n(Requires 1% battery drop for accurate calculation)")
                    Spacer()
                    if showExtrapolated && dropPerMinute > 0 && extrapolatedFullTime > 0 {
                        Text(formatTimeWithSeconds(extrapolatedFullTime))
                    } else {
                        Text("-")
                            .foregroundColor(.secondary)
                    }
                }
                HStack {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .foregroundColor(.blue)
                    LabelWithTooltip("Extrapolated Time Remaining:", 
                        tooltip: "Estimated time until battery depletes at current workload\n(Requires 1% battery drop for accurate calculation)")
                    Spacer()
                    if showExtrapolated && dropPerMinute > 0 && extrapolatedFullTime > 0 {
                        Text(formatTimeWithSeconds((currentBatteryLevel * 100) / dropPerMinute * 60))
                    } else {
                        Text("-")
                            .foregroundColor(.secondary)
                    }
                }
                if !showExtrapolated {
                    HStack {
                        Image(systemName: "hourglass")
                            .foregroundColor(.secondary)
                        Text("Waiting for at least 1% battery drop for accurate extrapolation...")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } else if dropPerMinute <= 0 || extrapolatedFullTime <= 0 {
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(.secondary)
                        Text("Calculating extrapolated values...")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
        }
        .padding(.vertical, 5)
    }
    
    private func formatTimeWithSeconds(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
    }
}
