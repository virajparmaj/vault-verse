import Foundation
import SwiftData
import VaultVerseCore

// SwiftData persistence models. These mirror the VaultVerseCore domain structs
// 1:1 and never leak outside the store — `SwiftDataVaultStore` maps to/from the
// neutral domain types so services and UI stay persistence-agnostic.
//
// Enums are stored as their String rawValue; nested Codable values (job errors,
// suggested matches, change summaries) are stored as JSON `Data` for simplicity.

enum SDJSON {
    static func encode<T: Encodable>(_ value: T?) -> Data? {
        guard let value else { return nil }
        return try? JSONEncoder().encode(value)
    }
    static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

@Model final class SDTrack {
    @Attribute(.unique) var id: String
    var title: String
    var normalizedTitle: String
    var primaryArtist: String
    var artists: [String]
    var normalizedArtist: String
    var album: String?
    var durationMs: Int?
    var isrc: String?
    var releaseDate: Date?
    var explicit: Bool?
    var artworkURL: String?
    var previewURL: String?
    var createdAt: Date
    var updatedAt: Date

    init(_ t: Track) {
        id = t.id; title = t.title; normalizedTitle = t.normalizedTitle
        primaryArtist = t.primaryArtist; artists = t.artists; normalizedArtist = t.normalizedArtist
        album = t.album; durationMs = t.durationMs; isrc = t.isrc; releaseDate = t.releaseDate
        explicit = t.explicit; artworkURL = t.artworkURL; previewURL = t.previewURL
        createdAt = t.createdAt; updatedAt = t.updatedAt
    }
    func apply(_ t: Track) {
        title = t.title; normalizedTitle = t.normalizedTitle; primaryArtist = t.primaryArtist
        artists = t.artists; normalizedArtist = t.normalizedArtist; album = t.album
        durationMs = t.durationMs; isrc = t.isrc; releaseDate = t.releaseDate; explicit = t.explicit
        artworkURL = t.artworkURL; previewURL = t.previewURL; updatedAt = t.updatedAt
    }
    func toDomain() -> Track {
        Track(id: id, title: title, normalizedTitle: normalizedTitle, primaryArtist: primaryArtist,
              artists: artists, normalizedArtist: normalizedArtist, album: album, durationMs: durationMs,
              isrc: isrc, releaseDate: releaseDate, explicit: explicit, artworkURL: artworkURL,
              previewURL: previewURL, createdAt: createdAt, updatedAt: updatedAt)
    }
}

@Model final class SDPlaylist {
    @Attribute(.unique) var id: String
    var title: String
    var detail: String?
    var sourceProvider: String
    var sourcePlaylistId: String?
    var artworkURL: String?
    var cachedArtworkPath: String?
    var trackCount: Int
    var originalOwnerName: String?
    var visibility: String
    var status: String
    var importedAt: Date
    var lastSyncedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(_ p: Playlist) {
        id = p.id; title = p.title; detail = p.description; sourceProvider = p.sourceProvider.rawValue
        sourcePlaylistId = p.sourcePlaylistId; artworkURL = p.artworkURL; cachedArtworkPath = p.cachedArtworkPath
        trackCount = p.trackCount; originalOwnerName = p.originalOwnerName; visibility = p.visibility.rawValue
        status = p.status.rawValue; importedAt = p.importedAt; lastSyncedAt = p.lastSyncedAt
        createdAt = p.createdAt; updatedAt = p.updatedAt
    }
    func apply(_ p: Playlist) {
        title = p.title; detail = p.description; sourceProvider = p.sourceProvider.rawValue
        sourcePlaylistId = p.sourcePlaylistId; artworkURL = p.artworkURL; cachedArtworkPath = p.cachedArtworkPath
        trackCount = p.trackCount; originalOwnerName = p.originalOwnerName; visibility = p.visibility.rawValue
        status = p.status.rawValue; importedAt = p.importedAt; lastSyncedAt = p.lastSyncedAt; updatedAt = p.updatedAt
    }
    func toDomain() -> Playlist {
        Playlist(id: id, title: title, description: detail,
                 sourceProvider: Provider(rawValue: sourceProvider) ?? .appleMusic,
                 sourcePlaylistId: sourcePlaylistId, artworkURL: artworkURL, cachedArtworkPath: cachedArtworkPath,
                 trackCount: trackCount, originalOwnerName: originalOwnerName,
                 visibility: Visibility(rawValue: visibility) ?? .isPrivate,
                 status: PlaylistStatus(rawValue: status) ?? .archived,
                 importedAt: importedAt, lastSyncedAt: lastSyncedAt, createdAt: createdAt, updatedAt: updatedAt)
    }
}

@Model final class SDSnapshot {
    @Attribute(.unique) var id: String
    var playlistId: String
    var snapshotName: String?
    var sourceProvider: String
    var sourcePlaylistId: String?
    var playlistTitle: String?
    var playlistArtworkURL: String?
    var trackCount: Int
    var checksum: String?
    var changeSummaryData: Data?
    var createdAt: Date

    init(_ s: PlaylistSnapshot) {
        id = s.id; playlistId = s.playlistId; snapshotName = s.snapshotName
        sourceProvider = s.sourceProvider.rawValue; sourcePlaylistId = s.sourcePlaylistId
        playlistTitle = s.playlistTitle; playlistArtworkURL = s.playlistArtworkURL
        trackCount = s.trackCount; checksum = s.checksum
        changeSummaryData = SDJSON.encode(s.changeSummary); createdAt = s.createdAt
    }
    func toDomain() -> PlaylistSnapshot {
        PlaylistSnapshot(id: id, playlistId: playlistId, snapshotName: snapshotName,
                         sourceProvider: Provider(rawValue: sourceProvider) ?? .appleMusic,
                         sourcePlaylistId: sourcePlaylistId, playlistTitle: playlistTitle,
                         playlistArtworkURL: playlistArtworkURL, trackCount: trackCount, checksum: checksum,
                         changeSummary: SDJSON.decode(SnapshotChangeSummary.self, changeSummaryData),
                         createdAt: createdAt)
    }
}

@Model final class SDSnapshotTrack {
    @Attribute(.unique) var id: String
    var snapshotId: String
    var trackId: String
    var position: Int
    var title: String
    var artistName: String
    var albumName: String?
    var durationMs: Int?
    var addedAtSource: Date?
    var addedBySource: String?
    var sourceProviderTrackId: String?
    var sourceProviderURI: String?
    var rawSourcePayload: String?
    var createdAt: Date

    init(_ t: SnapshotTrack) {
        id = t.id; snapshotId = t.snapshotId; trackId = t.trackId; position = t.position
        title = t.title; artistName = t.artistName; albumName = t.albumName; durationMs = t.durationMs
        addedAtSource = t.addedAtSource; addedBySource = t.addedBySource
        sourceProviderTrackId = t.sourceProviderTrackId; sourceProviderURI = t.sourceProviderURI
        rawSourcePayload = t.rawSourcePayload; createdAt = t.createdAt
    }
    func toDomain() -> SnapshotTrack {
        SnapshotTrack(id: id, snapshotId: snapshotId, trackId: trackId, position: position, title: title,
                      artistName: artistName, albumName: albumName, durationMs: durationMs,
                      addedAtSource: addedAtSource, addedBySource: addedBySource,
                      sourceProviderTrackId: sourceProviderTrackId, sourceProviderURI: sourceProviderURI,
                      rawSourcePayload: rawSourcePayload, createdAt: createdAt)
    }
}

@Model final class SDMapping {
    @Attribute(.unique) var id: String
    var trackId: String
    var provider: String
    var providerTrackId: String
    var providerURI: String?
    var providerURL: String?
    var catalogCountry: String?
    var matchMethod: String
    var confidenceScore: Int
    var isManualOverride: Bool
    var availabilityStatus: String
    var lastVerifiedAt: Date?
    var createdAt: Date

    init(_ m: TrackPlatformMapping) {
        id = m.id; trackId = m.trackId; provider = m.provider.rawValue; providerTrackId = m.providerTrackId
        providerURI = m.providerURI; providerURL = m.providerURL; catalogCountry = m.catalogCountry
        matchMethod = m.matchMethod.rawValue; confidenceScore = m.confidenceScore
        isManualOverride = m.isManualOverride; availabilityStatus = m.availabilityStatus.rawValue
        lastVerifiedAt = m.lastVerifiedAt; createdAt = m.createdAt
    }
    func toDomain() -> TrackPlatformMapping {
        TrackPlatformMapping(id: id, trackId: trackId, provider: Provider(rawValue: provider) ?? .appleMusic,
                             providerTrackId: providerTrackId, providerURI: providerURI, providerURL: providerURL,
                             catalogCountry: catalogCountry, matchMethod: MatchMethod(rawValue: matchMethod) ?? .none,
                             confidenceScore: confidenceScore, isManualOverride: isManualOverride,
                             availabilityStatus: AvailabilityStatus(rawValue: availabilityStatus) ?? .unknown,
                             lastVerifiedAt: lastVerifiedAt, createdAt: createdAt)
    }
}

@Model final class SDImportJob {
    @Attribute(.unique) var id: String
    var provider: String
    var connectedAccountId: String?
    var status: String
    var totalPlaylistsFound: Int
    var playlistsImported: Int
    var snapshotsCreated: Int
    var tracksImported: Int
    var errorsData: Data?
    var startedAt: Date
    var completedAt: Date?

    init(_ j: ImportJob) {
        id = j.id; provider = j.provider.rawValue; connectedAccountId = j.connectedAccountId
        status = j.status.rawValue; totalPlaylistsFound = j.totalPlaylistsFound
        playlistsImported = j.playlistsImported; snapshotsCreated = j.snapshotsCreated
        tracksImported = j.tracksImported; errorsData = SDJSON.encode(j.errors)
        startedAt = j.startedAt; completedAt = j.completedAt
    }
    func apply(_ j: ImportJob) {
        status = j.status.rawValue; connectedAccountId = j.connectedAccountId
        totalPlaylistsFound = j.totalPlaylistsFound; playlistsImported = j.playlistsImported
        snapshotsCreated = j.snapshotsCreated; tracksImported = j.tracksImported
        errorsData = SDJSON.encode(j.errors); completedAt = j.completedAt
    }
    func toDomain() -> ImportJob {
        ImportJob(id: id, provider: Provider(rawValue: provider) ?? .appleMusic, connectedAccountId: connectedAccountId,
                  status: JobStatus(rawValue: status) ?? .pending, totalPlaylistsFound: totalPlaylistsFound,
                  playlistsImported: playlistsImported, snapshotsCreated: snapshotsCreated, tracksImported: tracksImported,
                  errors: SDJSON.decode([JobError].self, errorsData) ?? [], startedAt: startedAt, completedAt: completedAt)
    }
}

@Model final class SDRestoreJob {
    @Attribute(.unique) var id: String
    var playlistId: String
    var snapshotId: String
    var targetProvider: String
    var targetConnectedAccountId: String?
    var status: String
    var totalTracks: Int
    var matchedTracks: Int
    var unmatchedTracks: Int
    var failedTracks: Int
    var createdTargetPlaylistId: String?
    var createdTargetPlaylistName: String?
    var errorsData: Data?
    var startedAt: Date
    var completedAt: Date?

    init(_ j: RestoreJob) {
        id = j.id; playlistId = j.playlistId; snapshotId = j.snapshotId; targetProvider = j.targetProvider.rawValue
        targetConnectedAccountId = j.targetConnectedAccountId; status = j.status.rawValue
        totalTracks = j.totalTracks; matchedTracks = j.matchedTracks; unmatchedTracks = j.unmatchedTracks
        failedTracks = j.failedTracks; createdTargetPlaylistId = j.createdTargetPlaylistId
        createdTargetPlaylistName = j.createdTargetPlaylistName; errorsData = SDJSON.encode(j.errors)
        startedAt = j.startedAt; completedAt = j.completedAt
    }
    func apply(_ j: RestoreJob) {
        status = j.status.rawValue; targetConnectedAccountId = j.targetConnectedAccountId
        totalTracks = j.totalTracks; matchedTracks = j.matchedTracks; unmatchedTracks = j.unmatchedTracks
        failedTracks = j.failedTracks; createdTargetPlaylistId = j.createdTargetPlaylistId
        createdTargetPlaylistName = j.createdTargetPlaylistName; errorsData = SDJSON.encode(j.errors)
        completedAt = j.completedAt
    }
    func toDomain() -> RestoreJob {
        RestoreJob(id: id, playlistId: playlistId, snapshotId: snapshotId,
                   targetProvider: Provider(rawValue: targetProvider) ?? .appleMusic,
                   targetConnectedAccountId: targetConnectedAccountId, status: JobStatus(rawValue: status) ?? .pending,
                   totalTracks: totalTracks, matchedTracks: matchedTracks, unmatchedTracks: unmatchedTracks,
                   failedTracks: failedTracks, createdTargetPlaylistId: createdTargetPlaylistId,
                   createdTargetPlaylistName: createdTargetPlaylistName,
                   errors: SDJSON.decode([JobError].self, errorsData) ?? [], startedAt: startedAt, completedAt: completedAt)
    }
}

@Model final class SDUnmatched {
    @Attribute(.unique) var id: String
    var restoreJobId: String
    var trackId: String
    var title: String
    var artist: String
    var album: String?
    var durationMs: Int?
    var attemptedProvider: String
    var reason: String
    var suggestedMatchesData: Data?
    var userSelectedMappingId: String?
    var resolvedAt: Date?
    var createdAt: Date

    init(_ u: UnmatchedTrack) {
        id = u.id; restoreJobId = u.restoreJobId; trackId = u.trackId; title = u.title; artist = u.artist
        album = u.album; durationMs = u.durationMs; attemptedProvider = u.attemptedProvider.rawValue
        reason = u.reason; suggestedMatchesData = SDJSON.encode(u.suggestedMatches)
        userSelectedMappingId = u.userSelectedMappingId; resolvedAt = u.resolvedAt; createdAt = u.createdAt
    }
    func apply(_ u: UnmatchedTrack) {
        reason = u.reason; suggestedMatchesData = SDJSON.encode(u.suggestedMatches)
        userSelectedMappingId = u.userSelectedMappingId; resolvedAt = u.resolvedAt
    }
    func toDomain() -> UnmatchedTrack {
        UnmatchedTrack(id: id, restoreJobId: restoreJobId, trackId: trackId, title: title, artist: artist,
                       album: album, durationMs: durationMs,
                       attemptedProvider: Provider(rawValue: attemptedProvider) ?? .appleMusic, reason: reason,
                       suggestedMatches: SDJSON.decode([SuggestedMatch].self, suggestedMatchesData) ?? [],
                       userSelectedMappingId: userSelectedMappingId, resolvedAt: resolvedAt, createdAt: createdAt)
    }
}

@Model final class SDExport {
    @Attribute(.unique) var id: String
    var playlistId: String?
    var snapshotId: String?
    var format: String
    var fileURL: String?
    var byteCount: Int?
    var createdAt: Date
    var expiresAt: Date?

    init(_ e: Export) {
        id = e.id; playlistId = e.playlistId; snapshotId = e.snapshotId; format = e.format.rawValue
        fileURL = e.fileURL; byteCount = e.byteCount; createdAt = e.createdAt; expiresAt = e.expiresAt
    }
    func toDomain() -> Export {
        Export(id: id, playlistId: playlistId, snapshotId: snapshotId,
               format: ExportFormat(rawValue: format) ?? .json, fileURL: fileURL, byteCount: byteCount,
               createdAt: createdAt, expiresAt: expiresAt)
    }
}

@Model final class SDAccount {
    @Attribute(.unique) var id: String
    var provider: String
    var providerUserId: String?
    var displayName: String?
    var scopes: [String]
    var storefront: String?
    var status: String
    var tokenKeychainRef: String?
    var connectedAt: Date
    var lastUsedAt: Date?

    init(_ a: ConnectedAccount) {
        id = a.id; provider = a.provider.rawValue; providerUserId = a.providerUserId; displayName = a.displayName
        scopes = a.scopes; storefront = a.storefront; status = a.status.rawValue
        tokenKeychainRef = a.tokenKeychainRef; connectedAt = a.connectedAt; lastUsedAt = a.lastUsedAt
    }
    func apply(_ a: ConnectedAccount) {
        providerUserId = a.providerUserId; displayName = a.displayName; scopes = a.scopes
        storefront = a.storefront; status = a.status.rawValue; tokenKeychainRef = a.tokenKeychainRef
        lastUsedAt = a.lastUsedAt
    }
    func toDomain() -> ConnectedAccount {
        ConnectedAccount(id: id, provider: Provider(rawValue: provider) ?? .appleMusic, providerUserId: providerUserId,
                         displayName: displayName, scopes: scopes, storefront: storefront,
                         status: ConnectionStatus(rawValue: status) ?? .connected, tokenKeychainRef: tokenKeychainRef,
                         connectedAt: connectedAt, lastUsedAt: lastUsedAt)
    }
}

/// The full SwiftData schema. Used when building the `ModelContainer`.
enum VaultSchema {
    static let models: [any PersistentModel.Type] = [
        SDTrack.self, SDPlaylist.self, SDSnapshot.self, SDSnapshotTrack.self, SDMapping.self,
        SDImportJob.self, SDRestoreJob.self, SDUnmatched.self, SDExport.self, SDAccount.self,
    ]
}
