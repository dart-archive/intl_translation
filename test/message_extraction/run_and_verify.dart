// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library verify_and_run;

import 'dart:convert';
import 'dart:io';

// TODO(devoncarew): See the comment below about restoring this testing.
// import 'sample_with_messages.dart' as sample;
// import 'verify_messages.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: run_and_verify [message_file.arb]');
    exit(0);
  }

  // TODO(devoncarew): This disables the verification of the generated code.
  // We'll want to restore testing it, but likely move to a more hygenic
  // integration style test, or, use a technique like golden masters.
  // // Verify message translation output
  // await sample.main();
  // verifyResult();

  // Messages with skipExtraction set should not be extracted.
  var fileArgs = args.where((x) => x.contains('.arb'));
  Map<String, dynamic> messages =
      jsonDecode(File(fileArgs.first).readAsStringSync());
  messages.forEach((name, _) {
    // Assume any name with 'skip' in it should not have been extracted.
    if (name.contains('skip')) {
      throw 'A skipped message was extracted: $name';
    }
  });
}
