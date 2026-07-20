import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/track.dart';

class DatabaseService {
  static Database? _db;
  static const String dbName = 'profiles.db';

  static Future<Database> get db async {
    if (_db != null) return _db!;
    // Initialize FFI for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    Directory dir = await getApplicationSupportDirectory();
    String path = p.join(dir.path, dbName);
    return await openDatabase(path, version: 1, onCreate: (d, v) async {
      await d.execute('''
        CREATE TABLE IF NOT EXISTS profiles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          languages TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await d.execute('''
        CREATE TABLE IF NOT EXISTS profile_artists (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER,
          artist_name TEXT,
          FOREIGN KEY(profile_id) REFERENCES profiles(id),
          UNIQUE(profile_id, artist_name)
        )
      ''');
      await d.execute('''
        CREATE TABLE IF NOT EXISTS listening_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER,
          title TEXT,
          artist TEXT,
          album TEXT,
          play_duration REAL DEFAULT 0,
          completed INTEGER DEFAULT 0,
          skipped INTEGER DEFAULT 0,
          played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(profile_id) REFERENCES profiles(id)
        )
      ''');
      await d.execute('''
        CREATE TABLE IF NOT EXISTS artist_affinity (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER,
          artist_name TEXT,
          play_count REAL DEFAULT 0,
          completed_count REAL DEFAULT 0,
          skip_count REAL DEFAULT 0,
          fav_count INTEGER DEFAULT 0,
          affinity_score REAL DEFAULT 0,
          last_updated TIMESTAMP,
          FOREIGN KEY(profile_id) REFERENCES profiles(id),
          UNIQUE(profile_id, artist_name)
        )
      ''');
      await d.execute('''
        CREATE TABLE IF NOT EXISTS taste_profile (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER,
          genre TEXT,
          percentage REAL DEFAULT 0,
          last_updated TIMESTAMP,
          FOREIGN KEY(profile_id) REFERENCES profiles(id),
          UNIQUE(profile_id, genre)
        )
      ''');
      await d.execute('''
        CREATE TABLE IF NOT EXISTS playlists (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER,
          name TEXT,
          type TEXT DEFAULT 'user',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(profile_id) REFERENCES profiles(id)
        )
      ''');
      await d.execute('''
        CREATE TABLE IF NOT EXISTS playlist_tracks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          playlist_id INTEGER,
          title TEXT,
          artist TEXT,
          album TEXT,
          artwork_url TEXT,
          added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(playlist_id) REFERENCES playlists(id)
        )
      ''');
      await d.execute('''
        CREATE TABLE IF NOT EXISTS recommendation_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER,
          rec_type TEXT,
          item_key TEXT,
          item_name TEXT,
          recommended_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(profile_id) REFERENCES profiles(id)
        )
      ''');
    });
  }

  static Future<int> ensureProfile(String name, List<String> languages) async {
    final d = await db;
    List<Map<String, dynamic>> existing = await d.query('profiles',
        where: 'name = ?', whereArgs: [name]);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    int id = await d.insert('profiles',
        {'name': name, 'languages': languages.join(',')});
    return id;
  }

  static Future<List<Map<String, dynamic>>> getProfiles() async {
    final d = await db;
    return await d.query('profiles');
  }

  static Future<void> saveProfileArtists(int pid, List<String> artists) async {
    final d = await db;
    await d.delete('profile_artists',
        where: 'profile_id = ?', whereArgs: [pid]);
    await d.transaction((txn) async {
      for (String a in artists) {
        await txn.insert('profile_artists',
            {'profile_id': pid, 'artist_name': a});
      }
    });
  }

  static Future<List<String>> getProfileArtists(int pid) async {
    final d = await db;
    var rows = await d.query('profile_artists',
        where: 'profile_id = ?', whereArgs: [pid]);
    return rows.map((r) => r['artist_name'] as String).toList();
  }

  static Future<void> logPlay(int pid, Track t, double duration,
      bool completed, bool skipped) async {
    final d = await db;
    await d.insert('listening_history', {
      'profile_id': pid,
      'title': t.title,
      'artist': t.artist,
      'album': t.album,
      'play_duration': duration,
      'completed': completed ? 1 : 0,
      'skipped': skipped ? 1 : 0,
    });
  }

  static Future<List<Map<String, dynamic>>> getListeningHistory(
      int pid, {int limit = 50}) async {
    final d = await db;
    return await d.query('listening_history',
        where: 'profile_id = ?',
        whereArgs: [pid],
        orderBy: 'id DESC',
        limit: limit);
  }

  static Future<List<Map<String, dynamic>>> getAffinities(int pid,
      {int limit = 20}) async {
    final d = await db;
    return await d.query('artist_affinity',
        where: 'profile_id = ?',
        whereArgs: [pid],
        orderBy: 'affinity_score DESC',
        limit: limit);
  }

  static Future<void> saveAffinities(
      int pid, List<Map<String, dynamic>> affs) async {
    final d = await db;
    await d.delete('artist_affinity',
        where: 'profile_id = ?', whereArgs: [pid]);
    await d.transaction((txn) async {
      for (var a in affs) {
        await txn.insert('artist_affinity', {
          'profile_id': pid,
          'artist_name': a['artist_name'],
          'play_count': a['play_count'],
          'completed_count': a['completed_count'],
          'skip_count': a['skip_count'],
          'fav_count': a['fav_count'],
          'affinity_score': a['affinity_score'],
          'last_updated': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  static Future<List<Map<String, dynamic>>> getTasteProfile(int pid) async {
    final d = await db;
    return await d.query('taste_profile',
        where: 'profile_id = ?',
        whereArgs: [pid],
        orderBy: 'percentage DESC');
  }

  static Future<void> saveTasteProfile(
      int pid, List<Map<String, dynamic>> tastes) async {
    final d = await db;
    await d.delete('taste_profile',
        where: 'profile_id = ?', whereArgs: [pid]);
    await d.transaction((txn) async {
      for (var t in tastes) {
        await txn.insert('taste_profile', {
          'profile_id': pid,
          'genre': t['genre'],
          'percentage': t['percentage'],
          'last_updated': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  static Future<void> addRecommendationHistory(
      int pid, String type, String key, String name) async {
    final d = await db;
    await d.insert('recommendation_history', {
      'profile_id': pid,
      'rec_type': type,
      'item_key': key,
      'item_name': name,
    });
  }

  static Future<Set<String>> getRecentRecommendations(
      int pid, String type) async {
    final d = await db;
    var rows = await d.rawQuery('''
      SELECT item_key FROM recommendation_history
      WHERE profile_id = ? AND rec_type = ?
      AND recommended_at >= datetime('now', '-7 days')
    ''', [pid, type]);
    return rows.map((r) => r['item_key'] as String).toSet();
  }

  static Future<List<Map<String, dynamic>>> getPlaylists(
      int pid, {String? type}) async {
    final d = await db;
    return await d.query('playlists',
        where: type != null
            ? 'profile_id = ? AND type = ?'
            : 'profile_id = ?',
        whereArgs: type != null ? [pid, type] : [pid],
        orderBy: 'id DESC');
  }

  static Future<int> createPlaylist(
      int pid, String name, String type) async {
    final d = await db;
    return await d.insert(
        'playlists', {'profile_id': pid, 'name': name, 'type': type});
  }

  static Future<List<Map<String, dynamic>>> getPlaylistTracks(
      int plid) async {
    final d = await db;
    return await d.query('playlist_tracks',
        where: 'playlist_id = ?', whereArgs: [plid]);
  }
}
