import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'audio/sfx.dart';
import 'monetize/services.dart';
import 'state/cloud_sync.dart';
import 'state/game_controller.dart';
import 'state/monetization.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final font in ['Coiny', 'PatrickHand']) {
      final text = await rootBundle.loadString('assets/fonts/$font-OFL.txt');
      yield LicenseEntryWithLineBreaks([font], text);
    }
  });
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  final controller = GameController();
  await controller.load();
  Sfx.instance.preload();
  final monetization = Monetization(game: controller, ads: createAds(), store: createStore());
  final cloud = CloudSync(game: controller, cloud: createCloud(), onAccount: monetization.identify);
  runApp(PenApp(controller: controller, monetization: monetization, cloud: cloud));
}
