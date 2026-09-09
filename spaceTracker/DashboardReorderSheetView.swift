//
//  DashboardReorderSheetView.swift
//  spaceTracker
//
//  FEAT-15: the drag-to-reorder UI for the Home Command dashboard's channel blocks,
//  reached from Settings. Uses a native List + onMove so the drag interaction itself
//  is the platform's own (reliable, familiar) implementation -- this view is just the
//  styling and the wiring into DashboardLayoutStore.

import SwiftUI

struct DashboardReorderSheetView: View {
    @ObservedObject var layoutStore: DashboardLayoutStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(layoutStore.channelOrder) { channel in
                        HStack(spacing: 12) {
                            Image(systemName: channel.systemImageName)
                                .font(.system(size: 14))
                                .foregroundColor(.cyan)
                                .frame(width: 20)
                            Text(channel.title.uppercased())
                                .font(.system(.footnote, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color(red: 0.06, green: 0.06, blue: 0.06))
                    }
                    .onMove { source, destination in
                        layoutStore.move(fromOffsets: source, toOffset: destination)
                    }
                } header: {
                    Text("DRAG TO REORDER")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                } footer: {
                    Text("Whatever you put first here shows first on Home Command, right under the sky map banner.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            // Forces drag handles to show immediately -- this sheet exists to reorder,
            // so there's no separate "Edit" mode to toggle into first.
            .environment(\.editMode, .constant(.active))
            .navigationTitle("DASHBOARD LAYOUT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        layoutStore.resetToDefault()
                    }
                    .foregroundColor(.orange)
                    .font(.system(.footnote, design: .monospaced))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cyan)
                        .fontWeight(.bold)
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}
