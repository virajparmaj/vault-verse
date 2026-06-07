import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case library = "Library"
    case restore = "Restore"
    case unmatched = "Unmatched"
    case exports = "Exports"
    case connections = "Connections"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "rectangle.3.group"
        case .library: return "square.stack"
        case .restore: return "arrow.uturn.backward.circle"
        case .unmatched: return "questionmark.diamond"
        case .exports: return "square.and.arrow.up.on.square"
        case .connections: return "link"
        case .settings: return "gearshape"
        }
    }
}

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var selection: SidebarItem? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            .safeAreaInset(edge: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("VaultVerse")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(VaultTheme.graphite)
                    Text("Your music memory, archived.")
                        .font(.caption)
                        .foregroundStyle(VaultTheme.mutedGrey)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(VaultTheme.brushedMetal)
            }
        } detail: {
            detail(for: selection ?? .dashboard)
                .background(VaultTheme.offWhite)
        }
    }

    @ViewBuilder
    private func detail(for item: SidebarItem) -> some View {
        switch item {
        case .dashboard: DashboardView()
        case .library: LibraryView()
        case .restore: RestoreView()
        case .unmatched: UnmatchedView()
        case .exports: ExportsView()
        case .connections: ConnectImportView()
        case .settings: SettingsView()
        }
    }
}
