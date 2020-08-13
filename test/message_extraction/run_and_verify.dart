// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library verify_and_run;

import 'dart:convert';
import 'dart:io';

import "package:test/test.dart";

import 'sample_with_messages.dart' as sample;
import 'verify_messages.dart';

main(List<String> args) {
  if (args.length == 0) {
    print('Usage: run_and_verify [message_file.arb]');
    exit(0);
  }

  test("Verify message translation output", () async {
    await sample.main();
    verifyResult();
  });

  test("Messages with skipExtraction set should not be extracted", () {
    var fileArgs = args.where((x) => x.contains('.arb'));
    var messages =
        new JsonCodec().decode(new File(fileArgs.first).readAsStringSync());
    messages.forEach((name, _) {
      // Assume any name with 'skip' in it should not have been extracted.
      expect(name, isNot(contains('skip')),
          reason: "A skipped message was extracted.");
    });
  });
}
