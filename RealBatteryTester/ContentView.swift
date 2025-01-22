import SwiftUI
import IOKit.ps

struct ContentView: View {
    @StateObject private var batteryMonitor = BatteryMonitor()
    @State private var selectedWorkload: Workload = .keepScreenOn
    @State private var isRunning = false
    
    var body: some View {
        TabView {
            BatteryStatusView()
                .tabItem {
                    Label("Test Battery", systemImage: "battery.100")
                }
            
            TestHistoryView()
                .tabItem {
                    Label("Test History", systemImage: "clock")
                }
        }
        .frame(minWidth: 600, minHeight: 750)
        .environmentObject(batteryMonitor)
    }
} 
