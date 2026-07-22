import '../../models/track.dart';

abstract class ItunesInterface {
  Future<String?> getArtistGenre(String artist);
  Future<List<Map<String, dynamic>>> searchByGenre(String genre, {String entity = 'musicArtist', int limit = 8});
  Future<List<Map<String, dynamic>>> searchAlbums(String query, {int limit = 8});
  Future<List<Track>> searchSongs(String query, {int limit = 15});
  Future<List<Map<String, dynamic>>> searchArtists(String query, {int limit = 12});
  List<Map<String, dynamic>> deduplicateArtists(List<Map<String, dynamic>> artists);
  Future<List<Track>> getArtistTopSongs(String artist);
  Future<List<Track>> getAlbumTracks(String album, String artist, {String? collectionId});
}
