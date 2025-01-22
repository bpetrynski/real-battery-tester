import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import CoreImage
import AppKit

enum Workload: String, CaseIterable, Identifiable, Codable {
    case keepScreenOn
    case browsing
    case videoPlayback
    case heavyLoad
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .keepScreenOn: return "Screen On"
        case .browsing: return "Browsing"
        case .videoPlayback: return "Video"
        case .heavyLoad: return "Heavy Load"
        }
    }
}

struct TestReport: Codable, Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let initialBatteryLevel: Double
    let finalBatteryLevel: Double
    let workload: Workload
    let initialEstimatedEndTime: Date
    let initialEstimatedDuration: TimeInterval
    let powerSource: String
    let temperature: Double
    let cycleCount: Int
    let maxCapacity: Int
    let designCapacity: Int
    let nominalCapacity: Int
    let timeRemaining: Int
    let isCharging: Bool
    let isCharged: Bool
    let amperage: Int
    let voltage: Double
    let wattage: Double
    let batteryHealth: String
    let batteryCondition: String
    let manufacturer: String
    let deviceName: String
    let systemVersion: String
    let notes: String
    
    init(startDate: Date, endDate: Date, initialBatteryLevel: Double, finalBatteryLevel: Double, workload: Workload, initialEstimatedEndTime: Date, initialEstimatedDuration: TimeInterval, powerSource: String, temperature: Double, cycleCount: Int, maxCapacity: Int, designCapacity: Int, nominalCapacity: Int, timeRemaining: Int, isCharging: Bool, isCharged: Bool, amperage: Int, voltage: Double, wattage: Double, batteryHealth: String, batteryCondition: String, manufacturer: String, deviceName: String, systemVersion: String, notes: String) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.initialBatteryLevel = initialBatteryLevel
        self.finalBatteryLevel = finalBatteryLevel
        self.workload = workload
        self.initialEstimatedEndTime = initialEstimatedEndTime
        self.initialEstimatedDuration = initialEstimatedDuration
        self.powerSource = powerSource
        self.temperature = temperature
        self.cycleCount = cycleCount
        self.maxCapacity = maxCapacity
        self.designCapacity = designCapacity
        self.nominalCapacity = nominalCapacity
        self.timeRemaining = timeRemaining
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.amperage = amperage
        self.voltage = voltage
        self.wattage = wattage
        self.batteryHealth = batteryHealth
        self.batteryCondition = batteryCondition
        self.manufacturer = manufacturer
        self.deviceName = deviceName
        self.systemVersion = systemVersion
        self.notes = notes
    }
    
    var percentageDrop: Double {
        (initialBatteryLevel - finalBatteryLevel) * 100
    }
    
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    var batteryDrain: Double {
        initialBatteryLevel - finalBatteryLevel
    }
    
    var drainRate: Double {
        batteryDrain / (duration / 3600)
    }
}

class BatteryMonitor: ObservableObject {
    @Published var batteryLevel: Double = 0
    @Published var isCharging: Bool = false
    @Published var estimatedTime: TimeInterval = 0
    @Published var lastTestReport: TestReport?
    @Published var testDuration: TimeInterval = 0
    @Published var testInProgress: Bool = false
    @Published var estimatedTestEndTime: Date?
    @Published var currentDropPerMinute: Double = 0
    @Published var currentExtrapolatedFullTime: TimeInterval = 0
    @Published var initialEstimatedEndTime: Date?
    @Published var initialEstimatedDuration: TimeInterval = 0
    @Published var allTestReports: [TestReport] = []
    
    var timer: Timer?
    var startTime: Date?
    var currentWorkload: Workload?
    private let reportURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("battery_reports.json")
    private let logURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("battery_test.log")
    private var sleepAssertion: IOPMAssertionID?
    private var workloadTasks: [DispatchWorkItem] = []
    private var isTestRunning = false
    private var testTimer: Timer?
    var initialBatteryLevel: Double = 0
    private var lastBatteryLevelUpdate: Date?
    
    init() {
        updateBatteryInfo()
        loadAllReports()
        loadLastReport()
        
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.updateBatteryInfo()
        }
    }
    
    deinit {
        stopTest()
    }
    
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        let logMessage = "\(timestamp): \(message)\n"
        
        do {
            if let data = logMessage.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logURL.path) {
                    let fileHandle = try FileHandle(forWritingTo: logURL)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                } else {
                    try logMessage.write(to: logURL, atomically: true, encoding: .utf8)
                }
            }
        } catch {
            print("Failed to write to log file: \(error)")
        }
    }
    
    func startTest(workload: Workload) {
        if isCharging {
            log("Cannot start test while charging")
            return
        }
        
        isTestRunning = true
        testInProgress = true
        startTime = Date()
        currentWorkload = workload
        testDuration = 0
        initialBatteryLevel = batteryLevel
        lastBatteryLevelUpdate = Date()
        
        // Calculate estimated end time
        initialEstimatedEndTime = Date().addingTimeInterval(estimatedTime)
        initialEstimatedDuration = estimatedTime
        estimatedTestEndTime = initialEstimatedEndTime
        
        log("Starting battery test with workload: \(workload.description)")
        log("Battery level at start: \(Int(batteryLevel * 100))%")
        log("Estimated time remaining: \(formatTime(estimatedTime))")
        
        // Start test duration timer
        testTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.testDuration += 1
            self.updateCurrentMetrics()
            
            if self.testDuration.truncatingRemainder(dividingBy: 60) == 0 {
                // Log status every minute
                self.log("Test running for: \(self.formatTime(self.testDuration))")
                self.log("Current battery level: \(Int(self.batteryLevel * 100))%")
                self.log("Drop per minute: \(String(format: "%.2f", self.currentDropPerMinute))%")
                self.log("Extrapolated full battery time: \(self.formatTime(self.currentExtrapolatedFullTime))")
            }
        }
        
        switch workload {
        case .keepScreenOn:
            preventSleep()
        case .browsing:
            preventSleep()
            simulateBrowsing()
        case .videoPlayback:
            preventSleep()
            simulateVideoPlayback()
        case .heavyLoad:
            preventSleep()
            simulateHeavyLoad()
        }
    }
    
    func stopTest() {
        guard isTestRunning else { return }
        
        isTestRunning = false
        testInProgress = false
        testTimer?.invalidate()
        testTimer = nil
        
        guard let startTime = startTime, let workload = currentWorkload else { return }
        
        let endTime = Date()
        let report = TestReport(
            startDate: startTime,
            endDate: endTime,
            initialBatteryLevel: initialBatteryLevel,
            finalBatteryLevel: batteryLevel,
            workload: workload,
            initialEstimatedEndTime: initialEstimatedEndTime ?? startTime,
            initialEstimatedDuration: initialEstimatedDuration,
            powerSource: "",
            temperature: 0,
            cycleCount: 0,
            maxCapacity: 0,
            designCapacity: 0,
            nominalCapacity: 0,
            timeRemaining: 0,
            isCharging: false,
            isCharged: false,
            amperage: 0,
            voltage: 0,
            wattage: 0,
            batteryHealth: "",
            batteryCondition: "",
            manufacturer: "",
            deviceName: "",
            systemVersion: "",
            notes: ""
        )
        
        log("Test completed")
        log("Final battery level: \(Int(batteryLevel * 100))%")
        log("Test duration: \(formatTime(report.duration))")
        log("Battery drop: \(String(format: "%.1f", report.percentageDrop))%")
        log("Drop per minute: \(String(format: "%.2f", report.drainRate))%")
        log("Extrapolated full battery time: \(formatTime(report.drainRate > 0 ? (100 * 60) / report.drainRate : 0))")
        
        saveReport(report)
        lastTestReport = report
        loadAllReports()
        
        // Stop workload simulation
        stopSimulation()
        allowSleep()
        
        self.startTime = nil
        self.currentWorkload = nil
        self.estimatedTestEndTime = nil
    }
    
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        return "\(hours)h \(minutes)m"
    }
    
    func updateBatteryInfo() {
        // "IOPSCopyPowerSourcesInfo" and "IOPSCopyPowerSourcesList" are "Copy" 
        // => use takeRetainedValue()
        guard let powerSourceInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            log("Failed to get power sources info")
            return
        }
        guard let powerSourcesList = IOPSCopyPowerSourcesList(powerSourceInfo)?.takeRetainedValue() as? [CFTypeRef] else {
            log("Failed to get power sources list")
            return
        }

        for sourceRef in powerSourcesList {
            // "IOPSGetPowerSourceDescription" is a "Get"
            // => use takeUnretainedValue()
            guard let descCF = IOPSGetPowerSourceDescription(powerSourceInfo, sourceRef) else {
                continue
            }
            guard let description = descCF.takeUnretainedValue() as? [String: AnyObject] else {
                continue
            }
            guard let type = description[kIOPSTypeKey] as? String,
                  type == kIOPSInternalBatteryType,
                  let capacity = description[kIOPSCurrentCapacityKey] as? Int,
                  let maxCapacity = description[kIOPSMaxCapacityKey] as? Int,
                  let isCharging = description[kIOPSIsChargingKey] as? Bool,
                  let timeRemaining = description[kIOPSTimeToEmptyKey] as? Int else {
                continue
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let previousLevel = self.batteryLevel
                self.batteryLevel = Double(capacity) / Double(maxCapacity)
                self.isCharging = isCharging
                self.estimatedTime = TimeInterval(timeRemaining * 60)
                
                if Int(previousLevel * 100) != Int(self.batteryLevel * 100) {
                    self.log("Battery level changed: \(Int(self.batteryLevel * 100))%")
                    
                    if Int(previousLevel * 100) / 5 != Int(self.batteryLevel * 100) / 5 || self.batteryLevel <= 0.02 {
                        self.saveIntermediateReport()
                    }
                }
                
                if self.batteryLevel <= 0.02 && self.testInProgress {
                    self.log("Critical battery level reached! Saving final report...")
                    self.stopTest()
                }
            }
            
            break
        }
    }
    
    private func saveIntermediateReport() {
        guard testInProgress,
              let startTime = startTime,
              let workload = currentWorkload else { return }
        
        let currentTime = Date()
        let intermediateReport = TestReport(
            startDate: startTime,
            endDate: currentTime,
            initialBatteryLevel: initialBatteryLevel,
            finalBatteryLevel: batteryLevel,
            workload: workload,
            initialEstimatedEndTime: initialEstimatedEndTime ?? startTime,
            initialEstimatedDuration: initialEstimatedDuration,
            powerSource: "",
            temperature: 0,
            cycleCount: 0,
            maxCapacity: 0,
            designCapacity: 0,
            nominalCapacity: 0,
            timeRemaining: 0,
            isCharging: false,
            isCharged: false,
            amperage: 0,
            voltage: 0,
            wattage: 0,
            batteryHealth: "",
            batteryCondition: "",
            manufacturer: "",
            deviceName: "",
            systemVersion: "",
            notes: ""
        )
        
        // Save to a separate file to avoid corrupting the main report
        let intermediateURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("battery_test_intermediate.json")
        
        do {
            let data = try JSONEncoder().encode(intermediateReport)
            try data.write(to: intermediateURL)
            log("Saved intermediate report at \(Int(batteryLevel * 100))% battery level")
        } catch {
            log("Failed to save intermediate report: \(error)")
        }
    }
    
    private func saveReport(_ report: TestReport) {
        var reports = loadReports()
        reports.append(report)
        
        do {
            let data = try JSONEncoder().encode(reports)
            try data.write(to: reportURL)
        } catch {
            print("Failed to save report: \(error)")
        }
    }
    
    private func loadReports() -> [TestReport] {
        do {
            let data = try Data(contentsOf: reportURL)
            return try JSONDecoder().decode([TestReport].self, from: data)
        } catch {
            return []
        }
    }
    
    private func loadAllReports() {
        allTestReports = loadReports()
    }
    
    private func loadLastReport() {
        let reports = loadReports()
        lastTestReport = reports.last
    }
    
    private func preventSleep() {
        var assertionID = IOPMAssertionID()
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Battery Life Test in Progress" as CFString,
            &assertionID
        )
        
        if result == kIOReturnSuccess {
            sleepAssertion = assertionID
        }
    }
    
    private func allowSleep() {
        if let assertion = sleepAssertion {
            IOPMAssertionRelease(assertion)
            sleepAssertion = nil
        }
    }
    
    private func simulateBrowsing() {
        let workItem = DispatchWorkItem { [weak self] in
            while self?.isTestRunning == true {
                // Simulate web browsing by downloading small files
                let urls = [
                    "https://www.apple.com",
                    "https://www.google.com",
                    "https://www.github.com"
                ]
                
                for url in urls {
                    guard let self = self, self.isTestRunning else { break }
                    if let url = URL(string: url) {
                        URLSession.shared.dataTask(with: url).resume()
                    }
                    Thread.sleep(forTimeInterval: 30) // Wait 30 seconds between requests
                }
            }
        }
        
        workloadTasks.append(workItem)
        DispatchQueue.global(qos: .background).async(execute: workItem)
    }
    
    private func simulateVideoPlayback() {
        let workItem = DispatchWorkItem { [weak self] in
            while self?.isTestRunning == true {
                // Simulate video playback by performing continuous image processing
                let size = CGSize(width: 1920, height: 1080)
                let renderer = CIContext()
                let filter = CIFilter(name: "CIGaussianBlur")!
                
                autoreleasepool {
                    let image = NSImage(size: size)
                    if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        let ciImage = CIImage(cgImage: cgImage)
                        filter.setValue(ciImage, forKey: kCIInputImageKey)
                        filter.setValue(10.0, forKey: kCIInputRadiusKey)
                        
                        if let output = filter.outputImage {
                            _ = renderer.createCGImage(output, from: output.extent)
                        }
                    }
                }
                
                Thread.sleep(forTimeInterval: 0.033) // ~30 fps
            }
        }
        
        workloadTasks.append(workItem)
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
    
    private func simulateHeavyLoad() {
        // Create multiple CPU-intensive tasks to utilize all cores
        let numberOfTasks = ProcessInfo.processInfo.processorCount
        
        for _ in 0..<numberOfTasks {
            let workItem = DispatchWorkItem { [weak self] in
                while self?.isTestRunning == true {
                    // Perform intensive calculations without sleep
                    autoreleasepool {
                        var result = 0.0
                        // Increased iterations and more complex calculations
                        for _ in 0..<1000000 {
                            result += sqrt(pow(sin(Double.random(in: 0...Double.pi)), 2) + 
                                        pow(cos(Double.random(in: 0...Double.pi)), 2)) *
                                    tan(Double.random(in: -Double.pi/2...Double.pi/2))
                        }
                        // Minimal sleep to prevent complete UI lockup
                        Thread.sleep(forTimeInterval: 0.001)
                    }
                }
            }
            
            workloadTasks.append(workItem)
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        }
        
        // Add memory pressure with larger allocations
        let memoryWorkItem = DispatchWorkItem { [weak self] in
            while self?.isTestRunning == true {
                autoreleasepool {
                    var dataArray: [Data] = []
                    // Allocate multiple chunks of memory
                    for _ in 0..<10 {
                        let data = Data(count: 10 * 1024 * 1024) // 10MB
                        dataArray.append(data)
                        _ = dataArray.map { $0.base64EncodedString() }
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
        }
        
        workloadTasks.append(memoryWorkItem)
        DispatchQueue.global(qos: .utility).async(execute: memoryWorkItem)
    }
    
    private func stopSimulation() {
        isTestRunning = false
        workloadTasks.forEach { $0.cancel() }
        workloadTasks.removeAll()
    }
    
    private func updateCurrentMetrics() {
        guard let startTime = startTime, let lastBatteryLevelUpdate = lastBatteryLevelUpdate else { return }
        
        let minutesElapsed = Date().timeIntervalSince(startTime) / 60
        let totalDrop = (initialBatteryLevel - batteryLevel) * 100
        
        currentDropPerMinute = minutesElapsed > 0 ? totalDrop / minutesElapsed : 0
        currentExtrapolatedFullTime = currentDropPerMinute > 0 ? (100 * 60) / currentDropPerMinute : 0
        
        // Update estimated end time based on current discharge rate
        if currentDropPerMinute > 0 {
            let remainingPercentage = batteryLevel * 100
            let remainingMinutes = remainingPercentage / currentDropPerMinute
            estimatedTestEndTime = Date().addingTimeInterval(remainingMinutes * 60)
        }
    }
} 