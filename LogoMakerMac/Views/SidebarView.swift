import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: AppStore
    @State private var alertFeature: String?
    var onSectionSelected: () -> Void = { }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#17131F"))
                    Text("Ai").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Logo Maker").font(.headline).foregroundStyle(.white)
                    Text("macOS • SwiftUI").font(.caption2).foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(AppTheme.headerGradient)

            VStack(spacing: 6) {
                ForEach(AppStore.AppSection.allCases) { section in
                    Button {
                        store.selectedSection = section
                        store.route.removeAll()
                        onSectionSelected()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section.icon).frame(width: 20)
                            Text(section.rawValue).fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(store.selectedSection == section ? AppTheme.gradientStart : AppTheme.primaryText)
                    .background {
                        if store.selectedSection == section {
                            RoundedRectangle(cornerRadius: 10).fill(AppTheme.gradientStart.opacity(0.10))
                        }
                    }
                }
            }
            .padding(12)

            Divider()
            VStack(spacing: 4) {
                sidebarAction("Upgrade", icon: "crown.fill")
                sidebarAction("Restore Purchase", icon: "arrow.clockwise")
                sidebarAction("Rate Us", icon: "star.fill")
                sidebarAction("Support", icon: "questionmark.circle.fill")
            }
            .padding(12)

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "diamond.fill")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Go Premium").font(.subheadline.bold())
                        Text("Unlock Everything").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button("UPGRADE NOW") { alertFeature = "Premium subscription" }
                    .buttonStyle(.plain)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 9).fill(AppTheme.upgradeOrange))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.separator))
            .padding(16)
        }
        .background(AppTheme.cardBackground)
        .alert("Under Development", isPresented: Binding(
            get: { alertFeature != nil },
            set: { if !$0 { alertFeature = nil } }
        )) {
            Button("OK", role: .cancel) { alertFeature = nil }
        } message: {
            Text("\(alertFeature ?? "This feature") is under development.")
        }
    }

    private func sidebarAction(_ title: String, icon: String) -> some View {
        Button {
            alertFeature = title
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 20)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }
}
