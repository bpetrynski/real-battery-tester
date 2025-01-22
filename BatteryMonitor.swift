import Foundation

class BatteryMonitor {
    func updateBatteryInfo() {
        guard let powerSourceInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            log("Failed to get power sources info")
            return
        }
        
        guard let sourcesList = IOPSCopyPowerSourcesList(powerSourceInfo)?.takeRetainedValue() else {
            log("Failed to get power sources list")
            return
        }
        
        let sourcesCount = CFArrayGetCount(sourcesList)
        for i in 0..<sourcesCount {
            guard let source = CFArrayGetValueAtIndex(sourcesList, i),
                  let description = IOPSGetPowerSourceDescription(powerSourceInfo, source)?.takeRetainedValue() as? [String: AnyObject],
                  let type = description[kIOPSTypeKey] as? String,
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
} 