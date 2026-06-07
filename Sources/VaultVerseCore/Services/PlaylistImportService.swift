import Foundation

public struct ImportProgress: Sendable, Hashable {
    public let totalPlaylists: Int
    public let processedPlaylists: Int
    public let currentPlaylistName: String?
    public let tracksImported: Int
}

/// Coordinates an import job: authenticate, fetch playlists/tracks, deduplicate
/// tracks into the neutral vault format, version each playlist as a snapshot, and
/// record provider mappings. Resilient by design — a single bad playlist or track
/// is recorded as a `JobError` and the import keeps going.
public struct PlaylistImportService: Sendable {
    private let connector: any MusicProviderConnector
    private let store: any VaultStore
    private let durationToleranceMs: Int

    public init(connector: any MusicProviderConnector, store: any VaultStore, durationToleranceMs: Int = 3000) {
        self.connector = connector
        self.store = store
        self.durationToleranceMs = durationToleranceMs
    }

    @discardableResult
    public func run(progress: (@Sendable (ImportProgress) -> Void)? = nil) async throws -> ImportJob {
        var job = ImportJob(provider: connector.provider, status: .running)
        try await store.upsertImportJob(job)

        let auth: AuthSession
        do {
            auth = try await connector.authenticate()
        } catch {
            job.status = .failed
            job.errors.append(JobError(scope: "auth", message: error.localizedDescription))
            job.completedAt = Date()
            try await store.upsertImportJob(job)
            throw error
        }

        await recordConnectedAccount(auth: auth, into: &job)

        let providerPlaylists = try await connector.fetchUserPlaylists(auth: auth)
        job.totalPlaylistsFound = providerPlaylists.count
        try await store.upsertImportJob(job)

        for (index, providerPlaylist) in providerPlaylists.enumerated() {
            progress?(ImportProgress(
                totalPlaylists: providerPlaylists.count,
                processedPlaylists: index,
                currentPlaylistName: providerPlaylist.name,
                tracksImported: job.tracksImported
            ))
            do {
                let result = try await importPlaylist(providerPlaylist, auth: auth)
                job.playlistsImported += 1
                job.tracksImported += result.tracksImported
                if result.createdSnapshot { job.snapshotsCreated += 1 }
                job.errors.append(contentsOf: result.errors)
            } catch {
                job.errors.append(JobError(scope: "playlist", itemIdentifier: providerPlaylist.providerPlaylistId, message: error.localizedDescription))
            }
        }

        job.status = job.errors.isEmpty ? .succeeded : .partial
        job.completedAt = Date()
        try await store.upsertImportJob(job)
        progress?(ImportProgress(
            totalPlaylists: providerPlaylists.count,
            processedPlaylists: providerPlaylists.count,
            currentPlaylistName: nil,
            tracksImported: job.tracksImported
        ))
        return job
    }

    // MARK: - Connected account

    private func recordConnectedAccount(auth: AuthSession, into job: inout ImportJob) async {
        guard let profile = try? await connector.fetchUserProfile(auth: auth) else { return }
        do {
            if var existing = try await store.account(provider: connector.provider) {
                existing.providerUserId = profile.providerUserId
                existing.displayName = profile.displayName
                existing.storefront = profile.storefront
                existing.status = .connected
                existing.tokenKeychainRef = auth.tokenKeychainRef
                existing.lastUsedAt = Date()
                try await store.upsertAccount(existing)
                job.connectedAccountId = existing.id
            } else {
                let account = ConnectedAccount(
                    provider: connector.provider,
                    providerUserId: profile.providerUserId,
                    displayName: profile.displayName,
                    scopes: ["library-read", "library-modify"],
                    storefront: profile.storefront,
                    status: .connected,
                    tokenKeychainRef: auth.tokenKeychainRef,
                    lastUsedAt: Date()
                )
                try await store.upsertAccount(account)
                job.connectedAccountId = account.id
            }
        } catch {
            job.errors.append(JobError(scope: "account", message: error.localizedDescription))
        }
    }

    // MARK: - Per-playlist import

    private struct PlaylistImportResult {
        let tracksImported: Int
        let createdSnapshot: Bool
        let errors: [JobError]
    }

    private func importPlaylist(_ providerPlaylist: ProviderPlaylist, auth: AuthSession) async throws -> PlaylistImportResult {
        let providerTracks = try await connector.fetchPlaylistTracks(auth: auth, providerPlaylistId: providerPlaylist.providerPlaylistId)

        var playlist = try await resolvePlaylist(providerPlaylist)
        let snapshotId = UUID().uuidString
        var snapshotTracks: [SnapshotTrack] = []
        var errors: [JobError] = []
        var tracksImported = 0

        for (position, providerTrack) in providerTracks.enumerated() {
            do {
                let track = try await resolveTrack(providerTrack)
                if !providerTrack.providerTrackId.isEmpty {
                    try await ensureSourceMapping(track: track, providerTrack: providerTrack, storefront: auth.storefront)
                }
                snapshotTracks.append(SnapshotTrack(
                    snapshotId: snapshotId,
                    trackId: track.id,
                    position: position,
                    title: providerTrack.title,
                    artistName: providerTrack.artistName,
                    albumName: providerTrack.albumName,
                    durationMs: providerTrack.durationMs,
                    addedAtSource: providerTrack.addedAt,
                    sourceProviderTrackId: providerTrack.providerTrackId.isEmpty ? nil : providerTrack.providerTrackId,
                    sourceProviderURI: providerTrack.providerURI,
                    rawSourcePayload: providerTrack.rawPayload
                ))
                tracksImported += 1
            } catch {
                errors.append(JobError(scope: "track", itemIdentifier: providerTrack.providerTrackId, message: error.localizedDescription))
            }
        }

        let checksum = SnapshotService.checksum(for: snapshotTracks)
        let previous = try await store.latestSnapshot(forPlaylist: playlist.id)

        // Re-import with no material change → don't create a duplicate snapshot.
        if let previous, previous.checksum == checksum {
            playlist.trackCount = snapshotTracks.count
            playlist.lastSyncedAt = Date()
            playlist.updatedAt = Date()
            try await store.upsertPlaylist(playlist)
            return PlaylistImportResult(tracksImported: tracksImported, createdSnapshot: false, errors: errors)
        }

        let previousTracks: [SnapshotTrack]?
        if let previous {
            previousTracks = try await store.snapshotTracks(snapshotId: previous.id)
        } else {
            previousTracks = nil
        }
        let summary = SnapshotService.changeSummary(previousTracks: previousTracks, newTracks: snapshotTracks)

        let snapshot = PlaylistSnapshot(
            id: snapshotId,
            playlistId: playlist.id,
            snapshotName: nil,
            sourceProvider: connector.provider,
            sourcePlaylistId: providerPlaylist.providerPlaylistId,
            playlistTitle: providerPlaylist.name,
            playlistArtworkURL: providerPlaylist.artworkURL,
            trackCount: snapshotTracks.count,
            checksum: checksum,
            changeSummary: summary
        )

        playlist.trackCount = snapshotTracks.count
        playlist.lastSyncedAt = Date()
        playlist.updatedAt = Date()
        playlist.status = .archived

        try await store.upsertPlaylist(playlist)
        try await store.insertSnapshot(snapshot, tracks: snapshotTracks)
        return PlaylistImportResult(tracksImported: tracksImported, createdSnapshot: true, errors: errors)
    }

    private func resolvePlaylist(_ providerPlaylist: ProviderPlaylist) async throws -> Playlist {
        if var existing = try await store.playlist(provider: connector.provider, sourcePlaylistId: providerPlaylist.providerPlaylistId) {
            existing.title = providerPlaylist.name
            existing.description = providerPlaylist.description
            existing.artworkURL = providerPlaylist.artworkURL
            existing.originalOwnerName = providerPlaylist.ownerName
            existing.visibility = providerPlaylist.isPublic ? .isPublic : .isPrivate
            existing.updatedAt = Date()
            return existing
        }
        return Playlist(
            title: providerPlaylist.name,
            description: providerPlaylist.description,
            sourceProvider: connector.provider,
            sourcePlaylistId: providerPlaylist.providerPlaylistId,
            artworkURL: providerPlaylist.artworkURL,
            originalOwnerName: providerPlaylist.ownerName,
            visibility: providerPlaylist.isPublic ? .isPublic : .isPrivate,
            status: .archived
        )
    }

    /// Dedup ladder: ISRC → normalized title+artist+duration → create new.
    private func resolveTrack(_ providerTrack: ProviderTrack) async throws -> Track {
        let normalizedTitle = TrackNormalizer.normalizeTitle(providerTrack.title)
        let normalizedArtist = TrackNormalizer.normalizeArtist(providerTrack.artistName)

        if let isrc = providerTrack.isrc, !isrc.isEmpty,
           let existing = try await store.trackByISRC(isrc) {
            return existing
        }
        if let existing = try await store.findTrack(
            normalizedTitle: normalizedTitle,
            normalizedArtist: normalizedArtist,
            durationMs: providerTrack.durationMs,
            toleranceMs: durationToleranceMs
        ) {
            return existing
        }

        let track = Track(
            title: providerTrack.title,
            normalizedTitle: normalizedTitle,
            primaryArtist: providerTrack.artistName,
            artists: providerTrack.artists.isEmpty ? [providerTrack.artistName] : providerTrack.artists,
            normalizedArtist: normalizedArtist,
            album: providerTrack.albumName,
            durationMs: providerTrack.durationMs,
            isrc: providerTrack.isrc,
            releaseDate: providerTrack.releaseDate,
            explicit: providerTrack.explicit,
            artworkURL: providerTrack.artworkURL
        )
        try await store.upsertTrack(track)
        return track
    }

    /// Records the authoritative source-provider mapping (the ID the track came
    /// from). Idempotent across re-imports.
    private func ensureSourceMapping(track: Track, providerTrack: ProviderTrack, storefront: String?) async throws {
        let already = try await store.mappings(forTrack: track.id)
            .contains { $0.provider == connector.provider && $0.providerTrackId == providerTrack.providerTrackId }
        if already { return }

        let method: MatchMethod = (providerTrack.isrc?.isEmpty == false) ? .isrc : .titleArtistDuration
        let mapping = TrackPlatformMapping(
            trackId: track.id,
            provider: connector.provider,
            providerTrackId: providerTrack.providerTrackId,
            providerURI: providerTrack.providerURI,
            providerURL: "https://music.apple.com/\(storefront ?? "us")/song/\(providerTrack.providerTrackId)",
            catalogCountry: storefront,
            matchMethod: method,
            confidenceScore: 100,
            isManualOverride: false,
            availabilityStatus: providerTrack.availability,
            lastVerifiedAt: Date()
        )
        try await store.upsertMapping(mapping)
    }
}
