import 'package:flutter/foundation.dart';
import '../services/interfaces/database_interface.dart';

class ProfileManager extends ChangeNotifier {
  final DatabaseInterface database;

  ProfileManager({required this.database});

  int? _profileId;
  List<String> _profileArtists = [];
  bool _isOnboarded = false;
  bool _loaded = false;

  int? get profileId => _profileId;
  List<String> get profileArtists => _profileArtists;
  bool get isOnboarded => _isOnboarded;
  bool get loaded => _loaded;

  Future<void> loadProfile(int id) async {
    _profileId = id;
    _profileArtists = await database.getProfileArtists(id);
    _isOnboarded = _profileArtists.length >= 3;
    _loaded = true;
    notifyListeners();
  }

  Future<void> tryLoadExistingProfile() async {
    if (_loaded) return;
    var profiles = await database.getProfiles();
    if (profiles.isNotEmpty) {
      await loadProfile(profiles.first['id'] as int);
    } else {
      _loaded = true;
    }
  }

  Future<int> createProfile(String name, List<String> languages) async {
    var id = await database.ensureProfile(name, languages);
    await loadProfile(id);
    return id;
  }

  Future<void> saveArtists(List<String> artists) async {
    if (_profileId == null) return;
    await database.saveProfileArtists(_profileId!, artists);
    _profileArtists = artists;
    _isOnboarded = artists.length >= 3;
    notifyListeners();
  }
}
