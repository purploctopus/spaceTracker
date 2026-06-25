//
//  NotificationManager.swift
//  spaceTracker
//
//  Created by Ben Clary on 6/25/26.
//  make an app colin loves

import Foundation
import UserNotifications
import Combine

class NotificationManager: ObservableObject {
    @Published var isAuthorized = false
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success {
                    print("✅ [NOTIFICATIONS]: System permission authorized by user.")
                } else {
                    print("❌ [NOTIFICATIONS]: System permission explicitly denied.")
                }
            }
        }
    }
    
    func scheduleDailyBriefing(launches: [SpaceLaunch], satellites: [SatellitePass], meteorShowers: [MeteorShower]) {
        // Wipe old briefings to avoid multiple repeating logs building up in the system stack
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let content = UNMutableNotificationContent()
        content.title = "🚀 DAILY ORBITAL BRIEFING"
        content.sound = .default
        
        var bodyLines: [String] = []
        
        // 1. Filter Rocket Flights launching TODAY
        let todayLaunches = launches.filter { launch in
            guard let netString = launch.net else { return false }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: netString) else { return false }
            return Calendar.current.isDateInToday(date)
        }
        
        if !todayLaunches.isEmpty {
            bodyLines.append("• LAUNCHES: \(todayLaunches.count) FLIGHT(S) ACTIVE FOR PAD IGNITION.")
        } else {
            bodyLines.append("• LAUNCHES: NO PAD IGNITIONS SCHEDULED.")
        }
        
        // 2. Filter Satellite Passes overhead TODAY
        let todaySats = satellites.filter { sat in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: sat.utcTimeISO) else { return false }
            return Calendar.current.isDateInToday(date)
        }
        
        if !todaySats.isEmpty {
            bodyLines.append("• SATELLITES: \(todaySats.count) VISUAL TARGETS PASSING OVERHEAD.")
        } else {
            bodyLines.append("• SATELLITES: SKY TRACKS AREA CLEAR.")
        }
        
        // 3. Filter Meteor Shower Peaks occurring TODAY
        let todayShowers = meteorShowers.filter { shower in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: shower.peakDateStr) else { return false }
            return Calendar.current.isDateInToday(date)
        }
        
        if let showerToday = todayShowers.first {
            bodyLines.append("• METEORS: \(showerToday.name.uppercased()) STREAMS PEAK TONIGHT!")
        }
        
        content.body = bodyLines.joined(separator: "\n")
        
        // Clock Trigger: Configured to fire every single morning at 08:00 AM local device time
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-space-briefing", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [NOTIFICATIONS]: Registration rejected: \(error.localizedDescription)")
            } else {
                print("✅ [NOTIFICATIONS]: Daily operations briefing locked for 08:00 AM local time.")
            }
        }
    }
}
