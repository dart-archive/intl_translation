// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Timeout(const Duration(seconds: 180))

library select_arg_order_test;

import "package:test/test.dart";

import "failed_extraction_test.dart";

main() {
  test("Expect failure because of out of order args", () {
    List<String> files = ['select_arg_order.dart'];
    runTestWithWarnings(
        warningsAreErrors: true,
        expectedExitCode: 1,
        embeddedPlurals: true,
        sourceFiles: files);
  });
}
