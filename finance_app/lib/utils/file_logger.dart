import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class CustomFileOutput extends LogOutput {
  final String fileName;
  final bool shouldOverride;
  File? _file;

  CustomFileOutput({this.fileName = 'app.log', this.shouldOverride = false});

  @override
  Future<void> init() async {
    super.init();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    if (shouldOverride && await file.exists()) {
      await file.delete();
    }
    _file = file;
  }

  @override
  void output(OutputEvent event) {
    _file?.writeAsStringSync('${event.lines.join('\n')}\n', mode: FileMode.append);
  }
}
