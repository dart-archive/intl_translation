// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Timeout(const Duration(seconds: 180))

library embedded_plural_text_after_test;

import "failed_extraction_test.dart";
import "package:test/test.dart";

main() {
  test("Expect failure because of embedded plural with text after it", () {
    List<String> specialFiles = ['embedded_plural_text_after.dart'];
    runTestWithWarnings(
        warningsAreErrors: true,
        expectedExitCode: 1,
        embeddedPlurals: false,
        sourceFiles: specialFiles);
  });
}
