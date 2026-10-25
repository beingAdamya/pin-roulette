// Adds Pin Roulette's Android pieces to the project that `flutter create`
// generates: the share-menu entry, internet access, the app name and the
// native MainActivity. Safe to run more than once.
//
//   flutter create --org com.pinroulette --project-name pin_roulette --platforms android .
//   dart tool/setup_android.dart
import 'dart:io';

void main() {
  final manifestFile = File('android/app/src/main/AndroidManifest.xml');
  if (!manifestFile.existsSync()) {
    stderr.writeln('No android/ folder yet. Run this first, from the project folder:\n'
        '  flutter create --org com.pinroulette --project-name pin_roulette --platforms android .');
    exit(1);
  }

  var m = manifestFile.readAsStringSync();

  if (!m.contains('android.permission.INTERNET')) {
    m = m.replaceFirst('<application',
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application');
  }

  m = m.replaceFirst(
      RegExp(r'android:label="[^"]*"'), 'android:label="Pin Roulette"');

  if (!m.contains('android.intent.action.SEND')) {
    const filter = '''            <!-- Lets Google Maps share places and saved lists into Pin Roulette -->
            <intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="text/plain"/>
            </intent-filter>
''';
    final close = m.indexOf('</activity>');
    if (close < 0) {
      stderr.writeln('Could not find </activity> in AndroidManifest.xml.');
      exit(1);
    }
    final lineStart = m.lastIndexOf('\n', close) + 1;
    m = m.substring(0, lineStart) + filter + m.substring(lineStart);
  }
  manifestFile.writeAsStringSync(m);

  final kotlinDir = Directory('android/app/src/main/kotlin');
  final activities = kotlinDir.existsSync()
      ? kotlinDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('MainActivity.kt'))
          .toList()
      : <File>[];
  if (activities.isEmpty) {
    stderr.writeln('Could not find MainActivity.kt under android/app/src/main/kotlin.');
    exit(1);
  }
  final activity = activities.first;
  final pkg = RegExp(r'^package\s+([\w.]+)', multiLine: true)
          .firstMatch(activity.readAsStringSync())
          ?.group(1) ??
      'com.pinroulette.pin_roulette';
  final template = File('tool/MainActivity.kt.txt').readAsStringSync();
  activity.writeAsStringSync(template.replaceFirst('__PACKAGE__', pkg));

  stdout.writeln('Android setup done: share target, internet access, app name and MainActivity.');
}
