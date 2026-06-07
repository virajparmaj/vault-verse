import Foundation

// MARK: - Preflight + report value types

public struct RestorePreflightItem: Sendable, Hashable, Identifiable {
    public enum Outcome: String, Sendable, Hashable {
        case confident   // safe to restore
        case review      // a match exists but is low-confidence
        case unavailable // found, but region-locked / not playable
        case unmatched   // nothing usable found
    }

    public var id: String { trackId }
    public let trackId: String
    public let position: Int
    public let title: String
    public let artist: String
    public let outcome: Outcome
    public let matchedProviderTrackId: String?
    public let score: Int?
    public let method: MatchMethod?
    public let availability: AvailabilityStatus?
    public let reason: String?
    public let suggestions: [SuggestedMatch]
}

public struct RestorePreflight: Sendable, Hashable {
    public let restoreJobId: String
    public let playlistId: String
    public let snapshotId: String
    public let targetProvider: Provider
    public let items: [RestorePreflightItem]

    public var confidentCount: Int { items.lazy.filter { $0.outcome == .confident }.count }
    public var reviewCount: Int { items.lazy.filter { $0.outcome == .review }.count }
    public var unavailableCount: Int { items.lazy.filter { $0.outcome == .unavailable }.count }
    public var unmatchedCount: Int { items.lazy.filter { $0.outcome == .unmatched }.count }
    public var total: Int { items.count }

    /// e.g. "20 confident · 1 review · 1 unavailable · 1 unmatched".
    public var summary: String {
        "\(confidentCount) confident · \(reviewCount) review · \(unavailableCount) unavailable · \(unmatchedCount) unmatched"
    }
}

public struct RestoreReport: Sendable, Hashable {
    public let restoreJobId: String
    public let targetProvider: Provider
    public let createdPlaylistId: String?
    public let createdPlaylistName: String?
    public let total: Int
    public let restored: Int
    public let skipped: Int
    public let failed: Int
    public let missingTracksCSVPath: String?
}

/// Runs the careful, transparent restore flow: preflight (no writes) → user
/// review/resolution → confirm (create playlist + add tracks) → report.
public struct PlaylistRestoreService: Sendable {
    private let connector: any MusicProviderConnector
    private let store: any VaultStore
    private let maxSuggestions: Int

    public init(connector: any MusicProviderConnector, store: any VaultStore, maxSuggestions: Int = 5) {
        self.connector = connector
        self.store = store
        self.maxSuggestions = maxSuggestions
    }

    // MARK: - Step 1: Preflight (no writes to the provider)

    public func preflight(snapshotId: String, targetProvider: Provider) async throws -> RestorePreflight {
        guard let snapshot = try await store.snapshot(id: snapshotId) else {
            throw VaultVerseError.snapshotNotFound(snapshotId)
        }
        let snapshotTracks = try await store.snapshotTracks(snapshotId: snapshotId)
        let auth = try await connector.authenticate()

        var job = RestoreJob(
            playlistId: snapshot.playlistId,
            snapshotId: snapshotId,
            targetProvider: targetProvider,
            status: .pending,
            totalTracks: snapshotTracks.count
        )
        try await store.upsertRestoreJob(job)

        var items: [RestorePreflightItem] = []
        var unmatchedRecords: [UnmatchedTrack] = []

        for snapshotTrack in snapshotTracks {
            let item = try await evaluate(
                snapshotTrack: snapshotTrack,
                targetProvider: targetProvider,
                auth: auth,
                restoreJobId: job.id,
                unmatchedRecords: &unmatchedRecords
            )
            items.append(item)
        }

        try await store.upsertUnmatched(unmatchedRecords)

        job.matchedTracks = items.lazy.filter { $0.outcome == .confident }.count
        job.unmatchedTracks = items.lazy.filter { $0.outcome == .review || $0.outcome == .unmatched }.count
        try await store.upsertRestoreJob(job)

        return RestorePreflight(
            restoreJobId: job.id,
            playlistId: snapshot.playlistId,
            snapshotId: snapshotId,
            targetProvider: targetProvider,
            items: items
        )
    }

    private func evaluate(
        snapshotTrack: SnapshotTrack,
        targetProvider: Provider,
        auth: AuthSession,
        restoreJobId: String,
        unmatchedRecords: inout [UnmatchedTrack]
    ) async throws -> RestorePreflightItem {
        let baseItem = { (outcome: RestorePreflightItem.Outcome, providerId: String?, score: Int?, method: MatchMethod?, availability: AvailabilityStatus?, reason: String?, suggestions: [SuggestedMatch]) in
            RestorePreflightItem(
                trackId: snapshotTrack.trackId,
                position: snapshotTrack.position,
                title: snapshotTrack.title,
                artist: snapshotTrack.artistName,
                outcome: outcome,
                matchedProviderTrackId: providerId,
                score: score,
                method: method,
                availability: availability,
                reason: reason,
                suggestions: suggestions
            )
        }

        // Manual overrides always win — this is the "remembered forever" behavior.
        if let manual = try await store.manualOverride(trackId: snapshotTrack.trackId, provider: targetProvider),
           !manual.providerTrackId.isEmpty {
            return baseItem(.confident, manual.providerTrackId, manual.confidenceScore, .manual, manual.availabilityStatus, "Manual match (saved)", [])
        }

        guard let track = try await store.track(id: snapshotTrack.trackId) else {
            unmatchedRecords.append(makeUnmatched(snapshotTrack, restoreJobId: restoreJobId, provider: targetProvider, reason: "Track missing from vault", suggestions: []))
            return baseItem(.unmatched, nil, nil, nil, nil, "Track missing from vault", [])
        }

        let query = TrackSearchQuery(
            isrc: track.isrc,
            title: track.title,
            artist: track.primaryArtist,
            album: track.album,
            durationMs: track.durationMs,
            storefront: auth.storefront
        )
        let candidates = try await connector.searchTrack(auth: auth, query: query)
        let suggestions = rankSuggestions(track: track, candidates: candidates, provider: targetProvider)

        guard let best = TrackMatchingService.bestMatch(for: track, in: candidates) else {
            let reason = snapshotTrack.sourceProviderTrackId == nil
                ? "Local-only item with no catalog ID"
                : "No match found in the \(targetProvider.displayName) catalog"
            unmatchedRecords.append(makeUnmatched(snapshotTrack, restoreJobId: restoreJobId, provider: targetProvider, reason: reason, suggestions: suggestions))
            return baseItem(.unmatched, nil, nil, nil, nil, reason, suggestions)
        }

        if best.candidate.availability == .regionUnavailable {
            let reason = "Unavailable in your \(auth.storefront ?? "current") storefront"
            unmatchedRecords.append(makeUnmatched(snapshotTrack, restoreJobId: restoreJobId, provider: targetProvider, reason: reason, suggestions: suggestions))
            return baseItem(.unavailable, best.candidate.providerTrackId, best.score, best.method, .regionUnavailable, reason, suggestions)
        }

        if best.score >= TrackMatchingService.confidentThreshold {
            try await persistMapping(trackId: track.id, provider: targetProvider, candidate: best.candidate, score: best.score, method: best.method, storefront: auth.storefront)
            return baseItem(.confident, best.candidate.providerTrackId, best.score, best.method, best.candidate.availability, nil, suggestions)
        }

        if best.score >= TrackMatchingService.reviewThreshold {
            let reason = "Low-confidence match (\(best.score)) — please review"
            unmatchedRecords.append(makeUnmatched(snapshotTrack, restoreJobId: restoreJobId, provider: targetProvider, reason: reason, suggestions: suggestions))
            return baseItem(.review, best.candidate.providerTrackId, best.score, best.method, best.candidate.availability, reason, suggestions)
        }

        let reason = "No confident match (best \(best.score))"
        unmatchedRecords.append(makeUnmatched(snapshotTrack, restoreJobId: restoreJobId, provider: targetProvider, reason: reason, suggestions: suggestions))
        return baseItem(.unmatched, best.candidate.providerTrackId, best.score, best.method, best.candidate.availability, reason, suggestions)
    }

    // MARK: - Step 2: Resolve a low/unmatched item (manual match memory)

    public func resolveMatch(
        restoreJobId: String,
        unmatchedTrackId: String,
        chosenProviderTrackId: String,
        providerURI: String? = nil,
        providerURL: String? = nil
    ) async throws {
        let unmatchedList = try await store.unmatched(forRestoreJob: restoreJobId)
        guard var record = unmatchedList.first(where: { $0.id == unmatchedTrackId }) else {
            throw VaultVerseError.unmatchedTrackNotFound(unmatchedTrackId)
        }

        let mapping = TrackPlatformMapping(
            trackId: record.trackId,
            provider: record.attemptedProvider,
            providerTrackId: chosenProviderTrackId,
            providerURI: providerURI,
            providerURL: providerURL,
            matchMethod: .manual,
            confidenceScore: 100,
            isManualOverride: true,
            availabilityStatus: .available,
            lastVerifiedAt: Date()
        )
        try await store.upsertMapping(mapping)

        record.userSelectedMappingId = mapping.id
        record.resolvedAt = Date()
        try await store.updateUnmatched(record)
    }

    // MARK: - Step 3: Confirm — create the playlist and add resolved tracks

    public func confirm(restoreJobId: String, newPlaylistName: String? = nil, exportsDirectory: URL? = nil) async throws -> RestoreReport {
        guard var job = try await store.restoreJob(id: restoreJobId) else {
            throw VaultVerseError.restoreJobNotFound(restoreJobId)
        }
        guard let snapshot = try await store.snapshot(id: job.snapshotId) else {
            throw VaultVerseError.snapshotNotFound(job.snapshotId)
        }
        let snapshotTracks = try await store.snapshotTracks(snapshotId: job.snapshotId)
        let auth = try await connector.authenticate()

        job.status = .running
        try await store.upsertRestoreJob(job)

        let playlistTitle: String
        if let title = snapshot.playlistTitle {
            playlistTitle = title
        } else if let playlist = try await store.playlist(id: snapshot.playlistId) {
            playlistTitle = playlist.title
        } else {
            playlistTitle = "Restored Playlist"
        }
        let name = newPlaylistName ?? "VaultVerse — \(playlistTitle)"

        // Resolve an ordered list of provider track IDs to add.
        var orderedIds: [String] = []
        var restoredTrackIds = Set<String>()
        for snapshotTrack in snapshotTracks {
            if let id = try await resolvedProviderTrackId(trackId: snapshotTrack.trackId, provider: job.targetProvider) {
                orderedIds.append(id)
                restoredTrackIds.insert(snapshotTrack.trackId)
            }
        }

        let created: CreatedPlaylist
        do {
            created = try await connector.createPlaylist(auth: auth, input: CreatePlaylistInput(name: name, description: "Restored by VaultVerse"))
        } catch {
            job.status = .failed
            job.errors.append(JobError(scope: "create-playlist", message: error.localizedDescription))
            job.completedAt = Date()
            try await store.upsertRestoreJob(job)
            throw error
        }

        let addResult: AddTracksResult
        if orderedIds.isEmpty {
            addResult = AddTracksResult(requested: 0, added: 0)
        } else {
            addResult = try await connector.addTracks(auth: auth, providerPlaylistId: created.providerPlaylistId, providerTrackIds: orderedIds)
        }

        let failedSet = Set(addResult.failedProviderTrackIds)
        let restored = addResult.added
        let failed = failedSet.count
        let total = snapshotTracks.count
        let skipped = max(0, total - orderedIds.count)

        // Missing-tracks CSV (anything not successfully restored).
        let missingURL = try await writeMissingCSV(
            snapshotTracks: snapshotTracks,
            restoredTrackIds: restoredTrackIds,
            addedProviderIds: Set(orderedIds).subtracting(failedSet),
            provider: job.targetProvider,
            playlistTitle: playlistTitle,
            directory: exportsDirectory
        )

        job.createdTargetPlaylistId = created.providerPlaylistId
        job.createdTargetPlaylistName = created.name
        job.matchedTracks = restored
        job.failedTracks = failed
        job.unmatchedTracks = skipped
        job.status = (failed == 0) ? .succeeded : .partial
        job.completedAt = Date()
        try await store.upsertRestoreJob(job)

        return RestoreReport(
            restoreJobId: job.id,
            targetProvider: job.targetProvider,
            createdPlaylistId: created.providerPlaylistId,
            createdPlaylistName: created.name,
            total: total,
            restored: restored,
            skipped: skipped,
            failed: failed,
            missingTracksCSVPath: missingURL?.path
        )
    }

    // MARK: - Helpers

    private func resolvedProviderTrackId(trackId: String, provider: Provider) async throws -> String? {
        if let manual = try await store.manualOverride(trackId: trackId, provider: provider), !manual.providerTrackId.isEmpty {
            return manual.providerTrackId
        }
        if let mapping = try await store.mapping(trackId: trackId, provider: provider),
           mapping.confidenceScore >= TrackMatchingService.confidentThreshold,
           mapping.availabilityStatus != .regionUnavailable,
           mapping.availabilityStatus != .notFound,
           !mapping.providerTrackId.isEmpty {
            return mapping.providerTrackId
        }
        return nil
    }

    private func persistMapping(trackId: String, provider: Provider, candidate: ProviderTrackSearchResult, score: Int, method: MatchMethod, storefront: String?) async throws {
        let alreadyManual = try await store.manualOverride(trackId: trackId, provider: provider) != nil
        if alreadyManual { return }
        let exists = try await store.mappings(forTrack: trackId).contains {
            $0.provider == provider && $0.providerTrackId == candidate.providerTrackId
        }
        if exists { return }
        let mapping = TrackPlatformMapping(
            trackId: trackId,
            provider: provider,
            providerTrackId: candidate.providerTrackId,
            providerURI: candidate.providerURI,
            providerURL: candidate.providerURL,
            catalogCountry: storefront,
            matchMethod: method,
            confidenceScore: score,
            isManualOverride: false,
            availabilityStatus: candidate.availability,
            lastVerifiedAt: Date()
        )
        try await store.upsertMapping(mapping)
    }

    private func rankSuggestions(track: Track, candidates: [ProviderTrackSearchResult], provider: Provider) -> [SuggestedMatch] {
        candidates
            .map { ($0, TrackMatchingService.score(track: track, candidate: $0)) }
            .sorted { $0.1.score > $1.1.score }
            .prefix(maxSuggestions)
            .map { candidate, match in
                SuggestedMatch(
                    provider: provider,
                    providerTrackId: candidate.providerTrackId,
                    providerURI: candidate.providerURI,
                    title: candidate.title,
                    artist: candidate.artistName,
                    album: candidate.albumName,
                    durationMs: candidate.durationMs,
                    confidenceScore: match.score,
                    matchMethod: match.method,
                    availability: candidate.availability
                )
            }
    }

    private func makeUnmatched(_ snapshotTrack: SnapshotTrack, restoreJobId: String, provider: Provider, reason: String, suggestions: [SuggestedMatch]) -> UnmatchedTrack {
        UnmatchedTrack(
            restoreJobId: restoreJobId,
            trackId: snapshotTrack.trackId,
            title: snapshotTrack.title,
            artist: snapshotTrack.artistName,
            album: snapshotTrack.albumName,
            durationMs: snapshotTrack.durationMs,
            attemptedProvider: provider,
            reason: reason,
            suggestedMatches: suggestions
        )
    }

    private func writeMissingCSV(
        snapshotTracks: [SnapshotTrack],
        restoredTrackIds: Set<String>,
        addedProviderIds: Set<String>,
        provider: Provider,
        playlistTitle: String,
        directory: URL?
    ) async throws -> URL? {
        let missing = snapshotTracks.filter { !restoredTrackIds.contains($0.trackId) }
        guard !missing.isEmpty else { return nil }
        let headers = ["position", "title", "artist", "album", "reason"]
        let rows = missing.map { track in
            [String(track.position + 1), track.title, track.artistName, track.albumName ?? "", "Not restored"]
        }
        let csv = ExportService.csv(headers: headers, rows: rows)
        guard let data = csv.data(using: .utf8) else { return nil }

        let dir = directory ?? ExportService.defaultExportsDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = "missing-\(playlistTitle)-\(Int(Date().timeIntervalSince1970))"
            .replacingOccurrences(of: " ", with: "-")
        let url = dir.appendingPathComponent(filename).appendingPathExtension("csv")
        try data.write(to: url, options: .atomic)
        return url
    }
}
