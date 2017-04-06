// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:intl_translation/extract_messages.dart';
import 'package:intl_translation/src/message_rewriter.dart';
import 'package:test/test.dart';

main() {
  group('findMessages', () {
    test('fails with message on call to Intl outside a method', () {
      final messageExtraction = new MessageExtraction();
      findMessages('List<String> list = [Intl.message("message")];', '',
          messageExtraction);

      expect(messageExtraction.warnings,
          anyElement(contains('Calls to Intl must be inside a method.')));
    });

    test('fails with message on non-literal examples Map', () {
      final messageExtraction = new MessageExtraction();
      findMessages(
          '''
final variable = 'foo';

String message(String string) =>
    Intl.select(string, {'foo': 'foo', 'bar': 'bar'},
        name: 'message', args: [string], examples: {'string': variable});
      ''',
          '',
          messageExtraction);

      expect(
          messageExtraction.warnings,
          anyElement(
              contains('Examples must be a Map literal, preferably const')));
    });

    test('fails with message on prefixed expression in interpolation', () {
      final messageExtraction = new MessageExtraction();
      findMessages(
          'String message(object) => Intl.message("\${object.property}");',
          '',
          messageExtraction);

      expect(
          messageExtraction.warnings,
          anyElement(
              contains('Only simple identifiers and Intl.plural/gender/select '
                  'expressions are allowed in message interpolation '
                  'expressions')));
    });
  });
}
