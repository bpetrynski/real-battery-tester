import SwiftUI

struct BatteryStatusView: View {
    @EnvironmentObject var batteryMonitor: BatteryMonitor
    @State private var selectedWorkload: Workload = .keepScreenOn
    @State private var isRunning: Bool = false
    @State private var showingLogs: Bool = false
    @State private var logContent: String = ""
    @State private var showingLogLocation: Bool = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
    private var logURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("battery_test.log")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // First Row with fixed 50/50 split
            GeometryReader { geometry in
                HStack(spacing: 20) {
                    // Battery Status (Top Left)
        GroupBox("General") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Battery Status:").bold()

                            HStack {
                                Image(systemName: "battery.100.bolt")
                                    .foregroundColor(batteryMonitor.isCharging ? .yellow : .green)
                                Text("Current Battery Level:")
                        Spacer()
                        Text("\(Int(batteryMonitor.batteryLevel * 100))%")
                                    .bold()
                            }
                            HStack {
                                Image(systemName: batteryMonitor.isCharging ? "bolt.fill" : "powerplug.fill")
                                    .foregroundColor(batteryMonitor.isCharging ? .yellow : .green)
                                Text("Power Status:")
                                Spacer()
                                Text(batteryMonitor.isCharging ? "Charging" : "On Battery")
                                    .foregroundColor(batteryMonitor.isCharging ? .yellow : .green)
                                    .bold()
                }
                    HStack {
                                Image(systemName: "clock.arrow.2.circlepath")
                                Text("macOS Estimated Battery Time:")
                                Spacer()
                                Text(formatTimeWithSeconds(batteryMonitor.estimatedTime))
                            }
                            
                            Text("Test Parameters:").bold()
                                .padding(.top, 5)
                            
                            Picker("CPU/GPU Workload:", selection: $selectedWorkload) {
                                ForEach(Workload.allCases) { workload in
                                    Text(workload.description).tag(workload)
                                }
                            }
                            .disabled(batteryMonitor.testInProgress)
                            Text("Initialize Test:").bold()
                                .padding(.top, 5)

                            Button(action: {
                                if batteryMonitor.testInProgress {
                                    batteryMonitor.stopTest()
                                } else {
                                    batteryMonitor.startTest(workload: selectedWorkload)
                                }
                            }) {
                                HStack {
                                    Image(systemName: batteryMonitor.testInProgress ? "stop.fill" : "play.fill")
                                    Text(batteryMonitor.testInProgress ? "Stop Test" : "Start Test")
                                }
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(batteryMonitor.isCharging)
                        }
                        .padding(.vertical, 5)
                    }
                    .frame(width: geometry.size.width * 0.5 - 10)
                    
                    // Test Instructions (Top Right)
                    GroupBox("Instructions") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.yellow)
                                Text("Before starting the test:")
                                    .bold()
                            }
                            Text("1. Unplug the charger")
                            Text("2. Close unnecessary applications")
                            Text("3. Set display brightness to desired level")
                            Text("4. Click 'Start Test' button")
                            
                            Text("During the test:").bold()
                            Text("• Do not plug in the charger")
                            Text("• Do not put computer to sleep")
                            
                            if batteryMonitor.isCharging {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Please unplug the charger to start the test")
                                        .foregroundColor(.red)
                                        .bold()
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .frame(width: geometry.size.width * 0.5 - 10)
                }
            }
            .frame(height: 250)
            .padding()
            
            Divider()
                .padding(.horizontal)
            
            // Second Row
            HStack(spacing: 20) {
                // Current Test Details (Bottom Left)
                GroupBox("Current Test") {
                    let batteryDrop = batteryMonitor.initialBatteryLevel - batteryMonitor.batteryLevel
                    TestDetailsView(
                        startTime: batteryMonitor.startTime,
                        duration: batteryMonitor.testDuration,
                        workload: batteryMonitor.currentWorkload,
                        initialBatteryLevel: batteryMonitor.initialBatteryLevel,
                        currentBatteryLevel: batteryMonitor.batteryLevel,
                        dropPerMinute: batteryMonitor.currentDropPerMinute,
                        initialEstimatedEnd: batteryMonitor.initialEstimatedEndTime,
                        currentEstimatedEnd: batteryMonitor.estimatedTestEndTime,
                        initialEstimatedDuration: batteryMonitor.initialEstimatedDuration,
                        extrapolatedFullTime: batteryMonitor.currentExtrapolatedFullTime,
                        isActive: batteryMonitor.testInProgress,
                        showExtrapolated: batteryDrop >= 0.01
                    )
                }
                
                // Previous Test Details (Bottom Right)
                GroupBox("Previous Test") {
                    if let lastReport = batteryMonitor.lastTestReport {
                        let batteryDrop = lastReport.initialBatteryLevel - lastReport.finalBatteryLevel
                        TestDetailsView(
                            startTime: lastReport.startDate,
                            duration: lastReport.duration,
                            workload: lastReport.workload,
                            initialBatteryLevel: lastReport.initialBatteryLevel,
                            currentBatteryLevel: lastReport.finalBatteryLevel,
                            dropPerMinute: lastReport.drainRate,
                            initialEstimatedEnd: lastReport.initialEstimatedEndTime,
                            currentEstimatedEnd: lastReport.endDate,
                            initialEstimatedDuration: lastReport.initialEstimatedDuration,
                            extrapolatedFullTime: lastReport.drainRate > 0 ? (100 * 60) / lastReport.drainRate : 0,
                            isActive: true,
                            showExtrapolated: batteryDrop >= 0.01
                        )
                    } else {
                        TestDetailsView(
                            startTime: nil,
                            duration: 0,
                            workload: nil,
                            initialBatteryLevel: 0,
                            currentBatteryLevel: 0,
                            dropPerMinute: 0,
                            initialEstimatedEnd: nil,
                            currentEstimatedEnd: nil,
                            initialEstimatedDuration: 0,
                            extrapolatedFullTime: 0,
                            isActive: false,
                            showExtrapolated: false
                        )
                    }
                }
            }
            .padding()
            
            // Bottom Buttons
            HStack {
                Button(action: {
                    loadLogContent()
                    showingLogs = true
                }) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                        Text("Show Logs")
                    }
                        .frame(maxWidth: .infinity)
                }
                
                Button(action: {
                    showingLogLocation = true
                }) {
                    HStack {
                        Image(systemName: "folder.fill")
                        Text("Show Logs Location")
                    }
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingLogs) {
            VStack {
                Text("Test Logs")
                    .font(.headline)
                    .padding()
                
                ScrollView {
                    Text(logContent)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                
                Button("Close") {
                    showingLogs = false
                }
                .padding()
            }
            .frame(width: 600, height: 400)
        }
        .alert("Logs Location", isPresented: $showingLogLocation) {
            Button("OK", role: .cancel) { }
            Button("Open in Finder") {
                NSWorkspace.shared.selectFile(logURL.path, inFileViewerRootedAtPath: "")
            }
        } message: {
            Text(logURL.path)
        }
    }
    
    private func loadLogContent() {
        do {
            logContent = try String(contentsOf: logURL, encoding: .utf8)
        } catch {
            logContent = "Error loading log file: \(error.localizedDescription)"
        }
    }
    
    private func formatTimeWithSeconds(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
    }
}
