// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library message_extraction_test;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Should we use deferred loading.
bool useDeferredLoading = true;

/// Should we generate JSON strings rather than code for messages.
bool useJson = false;

/// Should we generate the code for Flutter locale split.
///
/// Note that this is only supported in JSON mode.
bool useFlutterLocaleSplit = false;

String get _deferredLoadPrefix => useDeferredLoading ? '' : 'no-';

String get deferredLoadArg => '--${_deferredLoadPrefix}use-deferred-loading';

/// For testing we move the files into a temporary directory so as not to leave
/// generated files around after a failed test. For debugging, we omit that
/// step if [useLocalDirectory] is true. The place we move them to is saved as
/// [tempDir].
String get tempDir => _tempDir ?? (_tempDir = _createTempDir());
String _tempDir;
String _createTempDir() => useLocalDirectory
    ? '.'
    : Directory.systemTemp.createTempSync('message_extraction_test').path;

bool useLocalDirectory = false;

void main() {
  setUp(copyFilesToTempDirectory);
  tearDown(deleteGeneratedFiles);

  test(
      'Test round trip message extraction, translation, code generation, '
      'and printing', () async {
    var result = await extractMessages();
    _checkResult('extractMessages', result);

    result = await generateTranslationFiles();
    _checkResult('generateTranslationFiles', result);

    result = await generateCodeFromTranslation();
    _checkResult('generateCodeFromTranslation', result);

    result = await runAndVerify();
    _checkResult('runAndVerify', result);
  });
}

void copyFilesToTempDirectory() {
  if (useLocalDirectory) {
    return;
  }

  var files = [
    'arb_list.txt',
    'dart_list.txt',
    'embedded_plural_text_after.dart',
    'embedded_plural_text_before.dart',
    'mock_flutter/services.dart',
    'part_of_sample_with_messages.dart',
    'print_to_list.dart',
    'sample_with_messages.dart',
  ];

  for (var name in files) {
    var file = File(path.join('test', 'message_extraction', name));
    if (file.existsSync()) {
      // TODO: does this handle 'mock_flutter/services.dart' correctly?
      file.copySync(path.join(tempDir, path.basename(name)));
    }
  }
}

void deleteGeneratedFiles() {
  if (useLocalDirectory) return;

  try {
    Directory(tempDir).deleteSync(recursive: true);
  } on Error catch (e) {
    print('Failed to delete $tempDir: $e');
  }
}

/// Run the Dart script with the given set of args.
Future<ProcessResult> run(String script, List<String> args) {
  // Inject '--output-dir' in between the script and its arguments.
  return Process.run(
    Platform.executable,
    [
      path.absolute(script),
      '--output-dir=$tempDir',
      ...args,
    ],
    workingDirectory: tempDir,
  );
}

void _checkResult(String stepName, ProcessResult result) {
  expect(
    result.exitCode,
    0,
    reason:
        'step: $stepName\nstdout: ${result.stdout}\nstderr: ${result.stderr}',
  );
}

Future<ProcessResult> extractMessages() {
  return run(
    'bin/extract_to_arb.dart',
    [
      '--suppress-warnings',
      '--sources-list-file=dart_list.txt',
    ],
  );
}

Future<ProcessResult> generateTranslationFiles() {
  return run(
    'test/message_extraction/make_hardcoded_translation.dart',
    [
      'intl_messages.arb',
    ],
  );
}

Future<ProcessResult> generateCodeFromTranslation() {
  return run(
    'bin/generate_from_arb.dart',
    [
      deferredLoadArg,
      '--' + (useJson ? '' : 'no-') + 'json',
      '--' + (useFlutterLocaleSplit ? '' : 'no-') + 'flutter',
      '--flutter-import-path=.', // Mocks package:flutter/services.dart
      '--generated-file-prefix=foo_',
      '--sources-list-file=dart_list.txt',
      '--translations-list-file=arb_list.txt',
      '--no-null-safety',
    ],
  );
}

Future<ProcessResult> runAndVerify() {
  return run(
    'test/message_extraction/run_and_verify.dart',
    [
      'intl_messages.arb',
    ],
  );
}
