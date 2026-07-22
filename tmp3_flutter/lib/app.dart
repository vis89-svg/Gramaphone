import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/queue_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/player_bar.dart';

class Tmp3App extends StatelessWidget {
  const Tmp3App({super.key});

  static const Color bg = Color(0xFF0D1117);
  static const Color side = Color(0xFF11161D);
  static const Color card = Color(0xFF181E27);
  static const Color green = Color(0xFF1ED760);
  static const Color txt = Color(0xFFFFFFFF);
  static const Color txt2 = Color(0xFFA6B0BE);
  static const Color elev = Color(0xFF202733);
  static const Color txt3 = Color(0xFF727D8A);
  static const Color danger = Color(0xFFFF4D4F);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tmp3',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: green,
          surface: bg,
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _showOnboarding = false;
  StreamSubscription? _errSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboarding();
      _errSub = context.read<AppState>().audio.errorController.stream.listen((e) {
        if (e != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e, style: const TextStyle(color: Tmp3App.txt)),
              backgroundColor: Tmp3App.danger,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _errSub?.cancel();
    super.dispose();
  }

  Future<void> _checkOnboarding() async {
    var state = context.read<AppState>();
    await state.profile.tryLoadExistingProfile();
    if (mounted && !state.isOnboarded) {
      setState(() => _showOnboarding = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingScreen(
        onComplete: () => setState(() => _showOnboarding = false),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                HomeScreen(),
                SearchScreen(),
                QueueScreen(),
                StatsScreen(),
              ],
            ),
          ),
          const PlayerBar(),
          _buildNav(),
        ],
      ),
    );
  }

  Widget _buildNav() {
    return Container(
      color: Tmp3App.side,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          _navItem(0, Icons.home_rounded, 'Home'),
          _navItem(1, Icons.search_rounded, 'Search'),
          _navItem(2, Icons.queue_music_rounded, 'Queue'),
          _navItem(3, Icons.bar_chart_rounded, 'Stats'),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: selected ? Tmp3App.green : Tmp3App.txt3, size: 24),
              Text(label,
                  style: TextStyle(
                      color: selected ? Tmp3App.green : Tmp3App.txt3,
                      fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
