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
            sidebar
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
        } detail: {
            detail(for: selection ?? .dashboard)
                .background(VaultTheme.deepCocoa)
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader
            Divider().overlay(VaultTheme.brushedBronze)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(SidebarItem.allCases) { navRow($0) }
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            ZStack {
                VaultTheme.deepCocoa
                SpeakerGrilleTexture()
            }
            .ignoresSafeArea()
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            BrandEmblem(size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("VaultVerse")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(VaultTheme.warmCream)
                Text("Your music memory, archived.")
                    .font(.caption)
                    .foregroundStyle(VaultTheme.mutedTan)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func navRow(_ item: SidebarItem) -> some View {
        let selected = selection == item
        return Button {
            selection = item
        } label: {
            HStack(spacing: 9) {
                if selected {
                    RecordDot(diameter: 7)
                } else {
                    Color.clear.frame(width: 7, height: 7)
                }
                Image(systemName: item.icon).frame(width: 18)
                Text(item.rawValue)
                    .font(.subheadline.weight(selected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? VaultTheme.cherryPink : VaultTheme.mutedTan)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? VaultTheme.cherryPink.opacity(0.12) : Color.clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Detail router

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
