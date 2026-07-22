class Track {
  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final int duration;
  final String? youtubeId;
  final String? collectionId;
  final String? previewUrl;

  Track({
    required this.title,
    required this.artist,
    this.album = '',
    this.artworkUrl = '',
    this.duration = 0,
    this.youtubeId,
    this.collectionId,
    this.previewUrl,
  });

  factory Track.fromMap(Map<String, dynamic> m) => Track(
        title: m['trackName'] ?? m['title'] ?? '',
        artist: m['artistName'] ?? m['artist'] ?? '',
        album: m['collectionName'] ?? m['album'] ?? '',
        artworkUrl: m['artworkUrl100'] ?? m['artworkUrl60'] ?? '',
        duration: (m['trackTimeMillis'] ?? 0) ~/ 1000,
        collectionId: m['collectionId']?.toString(),
        previewUrl: m['previewUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'artist': artist,
        'album': album,
        'artworkUrl': artworkUrl,
        'duration': duration,
        'collectionId': collectionId,
      };

  String get dbKey => '$title||$artist';

  String get effectiveArtworkUrl =>
      artworkUrl.isNotEmpty
          ? artworkUrl
          : (youtubeId != null && youtubeId!.isNotEmpty
              ? 'https://img.youtube.com/vi/$youtubeId/mqdefault.jpg'
              : '');

  String get durationDisplay {
    if (duration <= 0) return '';
    var m = duration ~/ 60;
    var s = duration % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Track copyWith({String? youtubeId, String? artworkUrl}) => Track(
    title: title,
    artist: artist,
    album: album,
    artworkUrl: artworkUrl ?? this.artworkUrl,
    duration: duration,
    youtubeId: youtubeId ?? this.youtubeId,
    collectionId: collectionId,
    previewUrl: previewUrl,
  );
}
