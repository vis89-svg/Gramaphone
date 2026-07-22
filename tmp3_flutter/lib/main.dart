import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'providers/app_state.dart';
import 'services/interfaces/database_repository.dart';
import 'services/ytdlp_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  var state = AppState(
    database: DatabaseRepository(),
    ytDlp: YtDlpService(),
  );
  await state.audio.init();
  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: const Tmp3App(),
    ),
  );
}
