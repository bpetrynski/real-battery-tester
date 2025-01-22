import SwiftUI

struct TestHistoryView: View {
    @EnvironmentObject var batteryMonitor: BatteryMonitor
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var body: some View {
        VStack {
            Text("Test History")
                .font(.headline)
                .padding(.top)
            
            List(batteryMonitor.allTestReports.reversed()) { report in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Start: \(dateFormatter.string(from: report.startDate))")
                            Text("End: \(dateFormatter.string(from: report.endDate))")
                            Text("Duration: \(formatTimeWithSeconds(report.duration))")
                            Text("Workload: \(report.workload.description)")
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("Battery: \(Int(report.initialBatteryLevel * 100))% → \(Int(report.finalBatteryLevel * 100))%")
                            Text("Drop: \(String(format: "%.1f%%", report.percentageDrop))")
                            Text("Rate: \(String(format: "%.2f%%/min", report.drainRate))")
                            Text("Full Time: \(formatTimeWithSeconds(report.drainRate > 0 ? (100 * 60) / report.drainRate : 0))")
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("Initial Est. End: \(dateFormatter.string(from: report.initialEstimatedEndTime))")
                            Text("Initial Est. Duration: \(formatTimeWithSeconds(report.initialEstimatedDuration))")
                            Text("Actual Duration: \(formatTimeWithSeconds(report.duration))")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(minHeight: 300)
        }
        .padding()
    }
    
    private func formatTimeWithSeconds(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
    }
} 