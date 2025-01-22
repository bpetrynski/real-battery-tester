import SwiftUI

struct TestReportView: View {
    let report: TestReport
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        GroupBox("Last Test Report") {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    HStack {
                        Text("Start Time:")
                        Spacer()
                        Text(dateFormatter.string(from: report.startDate))
                    }
                    HStack {
                        Text("End Time:")
                        Spacer()
                        Text(dateFormatter.string(from: report.endDate))
                    }
                    HStack {
                        Text("Duration:")
                        Spacer()
                        Text(formatTime(report.duration))
                    }
                }
                
                Group {
                    HStack {
                        Text("Workload:")
                        Spacer()
                        Text(report.workload.description)
                    }
                    HStack {
                        Text("Battery Drop:")
                        Spacer()
                        Text(String(format: "%.1f%%", report.percentageDrop))
                    }
                    HStack {
                        Text("Drop Rate:")
                        Spacer()
                        Text(String(format: "%.2f%% per hour", report.drainRate))
                    }
                }
            }
            .padding(.vertical, 5)
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        return "\(hours)h \(minutes)m"
    }
} 