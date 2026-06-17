//
//  LaunchCountdownView.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/17/26.
//

import SwiftUI
import Combine

struct LaunchCountdownView: View {
    let targetDateString: String?
    @State private var timeRemainingString = "T-MINUS 00:00:00:00"
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(timeRemainingString)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.orange)
            .fontWeight(.bold)
            .tracking(1)
            .onReceive(timer) { _ in
                updateCountdown()
            }
            .onAppear {
                updateCountdown()
            }
    }
    
    private func updateCountdown() {
        guard let targetDateString = targetDateString else {
            timeRemainingString = "T-MINUS TIME TBD"
            return
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var targetDate = formatter.date(from: targetDateString)
        if targetDate == nil {
            let backup = ISO8601DateFormatter()
            targetDate = backup.date(from: targetDateString)
        }
        
        guard let validTarget = targetDate else {
            timeRemainingString = "T-MINUS TIME TBD"
            return
        }
        
        let diff = validTarget.timeIntervalSince(Date())
        
        if diff <= 0 {
            timeRemainingString = "LAUNCH OPERATIONAL / LIFTOFF PAST"
            return
        }
        
        let days = Int(diff) / 86400
        let hours = (Int(diff) % 86400) / 3600
        let minutes = (Int(diff) % 3600) / 60
        let seconds = Int(diff) % 60
        
        timeRemainingString = String(format: "T-MINUS %02d:%02d:%02d:%02d", days, hours, minutes, seconds)
    }
}
