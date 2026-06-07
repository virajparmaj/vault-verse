import SwiftUI
import VaultVerseCore

struct ExportsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var exports: [Export] = []
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Exports").font(.system(.title2, design: .rounded).weight(.semibold))
                    Text("Open backups. Every export is a portable copy — you are never locked into VaultVerse.")
                        .font(.subheadline).foregroundStyle(VaultTheme.mutedGrey)
                }
                if exports.isEmpty && loaded {
                    EmptyStateView(systemImage: "square.and.arrow.up", title: "No exports yet", message: "Export a playlist as JSON or CSV from its detail page.")
                } else {
                    ForEach(exports) { export in row(export) }
                }
            }
            .padding(24)
        }
        .navigationTitle("Exports")
        .background(VaultTheme.offWhite)
        .task { await load() }
    }

    private func row(_ export: Export) -> some View {
        HStack(spacing: 12) {
            Image(systemName: export.format == .json ? "doc.text" : "tablecells")
                .foregroundStyle(VaultTheme.actionBlue).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: export.fileURL ?? "—").lastPathComponent)
                    .font(.subheadline).foregroundStyle(VaultTheme.graphite)
                Text("\(export.format.rawValue.uppercased()) · \(sizeText(export.byteCount)) · \(export.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2).foregroundStyle(VaultTheme.mutedGrey)
            }
            Spacer()
            if let path = export.fileURL {
                Button { revealInFinder(path) } label: { Label("Show in Finder", systemImage: "folder") }
                    .buttonStyle(.bordered)
            }
        }
        .vaultCard()
    }

    private func sizeText(_ bytes: Int?) -> String {
        guard let bytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func load() async {
        exports = (try? await env.store.allExports()) ?? []
        loaded = true
    }
}
