// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Timeout(const Duration(seconds: 180))

library failed_extraction_test;

import "dart:io";

import "package:test/test.dart";

import "message_extraction_test.dart";

main() {
  test("Expect warnings but successful extraction", () {
    runTestWithWarnings(warningsAreErrors: false, expectedExitCode: 0);
  });
}

const List<String> defaultFiles = const [
  "sample_with_messages.dart",
  "part_of_sample_with_messages.dart"
];

void runTestWithWarnings(
    {bool warningsAreErrors = false,
    int expectedExitCode = 100,
    bool embeddedPlurals: true,
    List<String> sourceFiles: defaultFiles}) {
  verify(ProcessResult result) {
    try {
      expect(result.exitCode, expectedExitCode);
    } finally {
      deleteGeneratedFiles();
    }
  }

  copyFilesToTempDirectory();
  var program = asTestDirPath("../../bin/extract_to_arb.dart")!;
  List<String> args = ["--output-dir=$tempDir"];
  if (warningsAreErrors) {
    args.add('--warnings-are-errors');
  }
  if (!embeddedPlurals) {
    args.add('--no-embedded-plurals');
  }
  var files = sourceFiles.map((x) => asTempDirPath(x)!).toList();
  List<String> allArgs = [program]..addAll(args)..addAll(files);
  var callback = expectAsync1(verify);

  run(null, allArgs).then(callback);
}

typedef dynamic ThenArgument(ProcessResult _);
