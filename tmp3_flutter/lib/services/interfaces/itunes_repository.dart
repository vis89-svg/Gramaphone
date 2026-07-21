import '../../models/track.dart';
import '../itunes_service.dart';
import 'itunes_interface.dart';

class ItunesRepository implements ItunesInterface {
  @override
  Future<String?> getArtistGenre(String artist) =>
      ItunesService.getArtistGenre(artist);

  @override
  Future<List<Map<String, dynamic>>> searchByGenre(String genre,
          {String entity = 'musicArtist', int limit = 8}) =>
      ItunesService.searchByGenre(genre, entity: entity, limit: limit);

  @override
  Future<List<Map<String, dynamic>>> searchAlbums(String query,
          {int limit = 8}) =>
      ItunesService.searchAlbums(query, limit: limit);

  @override
  Future<List<Track>> searchSongs(String query, {int limit = 15}) =>
      ItunesService.searchSongs(query, limit: limit);

  @override
  Future<List<Map<String, dynamic>>> searchArtists(String query,
          {int limit = 12}) =>
      ItunesService.searchArtists(query, limit: limit);

  @override
  List<Map<String, dynamic>> deduplicateArtists(
          List<Map<String, dynamic>> artists) =>
      ItunesService.deduplicateArtists(artists);

  @override
  Future<List<Track>> getArtistTopSongs(String artist) =>
      ItunesService.getArtistTopSongs(artist);

  @override
  Future<List<Track>> getAlbumTracks(String album, String artist,
          {String? collectionId}) =>
      ItunesService.getAlbumTracks(album, artist, collectionId: collectionId);
}
