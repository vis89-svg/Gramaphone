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
}
