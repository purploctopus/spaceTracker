//
//  SystemConnectivityMonitor.swift
//  spaceTracker
//
//  Created by Ben Clary on 7/8/26.
//  MAKE AN APP COLIN LOVES

import Foundation
import Network
import Combine

// MARK: - 📡 GLOBAL CORE CONNECTIONS TELEMETRY MONITOR
@MainActor
class SystemConnectivityMonitor: ObservableObject {
    @Published var isSystemOnline: Bool = true
    
    private let pathMonitor = NWPathMonitor()
    private let monitoringQueue = DispatchQueue(label: "SystemConnectivityMonitorQueue")
    
    init() {
        // 💡 FIXED: Remove weak self capture entirely from the outer closure to pass Swift 6 thread inspections
        pathMonitor.pathUpdateHandler = { path in
            let onlineStatus = (path.status == .satisfied)
            
            // 💡 Safely hop straight onto the MainActor thread to apply your published state flags cleanly
            Task { @MainActor in
                self.isSystemOnline = onlineStatus
                print("📡 [SYSTEM TELEMETRY]: Core link status changed. Connected: \(onlineStatus)")
            }
        }
        pathMonitor.start(queue: monitoringQueue)
    }
}
