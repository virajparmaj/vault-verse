import Foundation
import AppKit

/// mm:ss from milliseconds.
func formatDuration(_ ms: Int?) -> String {
    guard let ms else { return "—" }
    let totalSeconds = ms / 1000
    return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
}

/// Reveal an exported file in Finder (works under the user-selected file sandbox).
func revealInFinder(_ path: String) {
    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
}
