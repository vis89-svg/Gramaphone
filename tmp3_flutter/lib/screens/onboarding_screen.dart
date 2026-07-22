import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/itunes_service.dart';
import '../app.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final _nameCtrl = TextEditingController(text: 'Me');
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedArtists = {};
  List<Map<String, dynamic>> _searchResults = [];
  bool _loading = false;
  final List<String> _selectedLanguages = ['English'];

  final List<Map<String, dynamic>> _allLanguages = [
    {'name': 'English', 'flag': '🇺🇸'},
    {'name': 'Hindi', 'flag': '🇮🇳'},
    {'name': 'Tamil', 'flag': '🇮🇳'},
    {'name': 'Telugu', 'flag': '🇮🇳'},
    {'name': 'Punjabi', 'flag': '🇮🇳'},
    {'name': 'Spanish', 'flag': '🇪🇸'},
    {'name': 'Korean', 'flag': '🇰🇷'},
    {'name': 'Japanese', 'flag': '🇯🇵'},
    {'name': 'French', 'flag': '🇫🇷'},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search() async {
    var q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    var results = await ItunesService.searchArtists(q);
    setState(() {
      _searchResults = results;
      _loading = false;
    });
  }

  Future<void> _done() async {
    if (_selectedArtists.length < 3) return;
    var state = context.read<AppState>();
    await state.createProfile(_nameCtrl.text.trim(), _selectedLanguages);
    await state.saveArtists(_selectedArtists.toList());
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tmp3App.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _step == 0 ? _buildStep1() : _buildStep2(),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Text('Welcome to tmp3',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Tmp3App.txt)),
        const SizedBox(height: 8),
        Text("Let's personalize your experience",
            style: TextStyle(fontSize: 14, color: Tmp3App.txt2)),
        const SizedBox(height: 32),
        Text('Your Name',
            style: TextStyle(fontSize: 12, color: Tmp3App.txt3)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          style: const TextStyle(color: Tmp3App.txt),
          decoration: InputDecoration(
            filled: true,
            fillColor: Tmp3App.card,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 24),
        Text('Languages',
            style: TextStyle(fontSize: 12, color: Tmp3App.txt3)),
        const SizedBox(height: 8),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allLanguages.map((l) {
              var name = l['name'] as String;
              var selected = _selectedLanguages.contains(name);
              return ChoiceChip(
                label: Text('${l['flag']} $name'),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedLanguages.add(name);
                    } else {
                      _selectedLanguages.remove(name);
                    }
                  });
                },
                selectedColor: Tmp3App.green,
                backgroundColor: Tmp3App.card,
                labelStyle: TextStyle(
                    color: selected ? Colors.black : Tmp3App.txt),
              );
            }).toList(),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() => _step = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: Tmp3App.green,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('Pick 3+ Favorite Artists',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Tmp3App.txt)),
        const SizedBox(height: 8),
        Text('Search for artists you love',
            style: TextStyle(fontSize: 14, color: Tmp3App.txt2)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Tmp3App.txt),
                decoration: InputDecoration(
                  hintText: 'Search artists...',
                  hintStyle: TextStyle(color: Tmp3App.txt3),
                  filled: true,
                  fillColor: Tmp3App.card,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  prefixIcon:
                      Icon(Icons.search, color: Tmp3App.txt3),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _search,
              icon: Icon(Icons.search, color: Tmp3App.green),
            ),
          ],
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Text('Search for your favorite artists',
                        style: TextStyle(color: Tmp3App.txt3)))
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (_, i) {
                      var x = _searchResults[i];
                      var name = x['artistName'] as String;
                      var selected = _selectedArtists.contains(name);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              selected ? Tmp3App.green : Tmp3App.card,
                          child: Text(name[0].toUpperCase(),
                              style: TextStyle(
                                  color: selected
                                      ? Colors.black
                                      : Tmp3App.txt)),
                        ),
                        title: Text(name,
                            style: TextStyle(color: Tmp3App.txt)),
                        subtitle: Text(x['primaryGenreName'] ?? '',
                            style: TextStyle(color: Tmp3App.txt3)),
                        trailing: Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color:
                              selected ? Tmp3App.green : Tmp3App.txt3,
                        ),
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedArtists.remove(name);
                            } else {
                              _selectedArtists.add(name);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        const SizedBox(height: 8),
        Text('${_selectedArtists.length} selected (need 3+)',
            style: TextStyle(color: Tmp3App.txt3)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedArtists.length >= 3 ? _done : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Tmp3App.green,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Tmp3App.card,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('Get Started',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
