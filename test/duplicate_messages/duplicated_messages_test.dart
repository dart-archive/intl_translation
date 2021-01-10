import 'dart:io';

import 'package:test/test.dart';

import '../../bin/extract_to_arb.dart' as extract;
import '../../bin/generate_from_arb.dart' as generate;

void main() {
  test('Should generate unique message map', () async {
    _generateArb('messages_pt');
    _generateArb('messages_en');

    var files = ['messages_pt', 'messages_en'];
    _generateMessages(files);
    await _assert('greet', files);
  });
}

const testFolder = 'test/duplicate_messages';
const outputFolder = '$testFolder/output';
final currDir = Directory.current.absolute.path;

void _generateArb(String fileName) {
  extract.main([
    '--output-file',
    './$outputFolder/$fileName.arb',
    './$testFolder/$fileName.dart'
  ]);
}

void _generateMessages(List<String> files) {
  final fileArgs = files.expand((file) => [
        './$testFolder/$file.dart',
        './$outputFolder/$file.arb',
      ]);

  generate.main([
    '--output-dir',
    outputFolder,
    ...fileArgs,
  ]);
}

void _assert(String key, List<String> files) async {
  for (final element in files.map((e) => '$currDir/$outputFolder/$e')) {
    final file = File("$element.dart");
    final fileLines = await file.readAsLines();
    final linesWithKey = fileLines
        .map((e) => e.trimLeft())
        .where((element) => element.startsWith("\"$key\" :"))
        .length;
    expect(linesWithKey, 1, reason: 'File $file has duplicated keys');
  }
}
