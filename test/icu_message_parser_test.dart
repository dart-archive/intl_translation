// @dart=2.10
import 'package:intl_translation/src/intl_message.dart';
import 'package:intl_translation/src/message_parser.dart';
import 'package:test/test.dart';

void main() {
  test('Simple case', () {
    String input = '''{gender_of_host, select, "
  "female {"
    "{num_guests, plural, offset:1 "
      "=0 {{host} does not give a party.}"
      "=1 {{host} invites {guest} to her party.}"
      "=2 {{host} invites {guest} and one other person to her party.}"
      "other {{host} invites {guest} and # other people to her party.}}}"
  "male {"
    "{num_guests, plural, offset:1 "
      "=0 {{host} does not give a party.}"
      "=1 {{host} invites {guest} to his party.}"
      "=2 {{host} invites {guest} and one other person to his party.}"
      "other {{host} invites {guest} and # other people to his party.}}}"
  "other {"
    "{num_guests, plural, offset:1 "
      "=0 {{host} does not give a party.}"
      "=1 {{host} invites {guest} to their party.}"
      "=2 {{host} invites {guest} and one other person to their party.}"
      "other {{host} invites {guest} and # other people to their party.}}}}''';
    Message parsedMessage = MessageParser(input).pluralAndGenderParse();
    print(parsedMessage);
    Message expectedMessage = Select.from(
      'gender_of_host',
      [
        [
          'female',
          Plural.from(
            'num_guests',
            [
              ['=0', '{{host} does not give a party.}'],
              ['=1', '{{host} invites {guest} to her party.}'],
              [
                '=2',
                '{{host} invites {guest} and one other person to her party.}'
              ],
              [
                'other',
                '{{host} invites {guest} and # other people to her party.}}}'
              ],
            ],
            null,
          )
        ],
        [
          'male',
          Plural.from(
            'num_guests',
            [
              ['=0', '{{host} does not give a party.}'],
              ['=1', '{{host} invites {guest} to his party.}'],
              [
                '=2',
                '{{host} invites {guest} and one other person to his party.}'
              ],
              [
                'other',
                '{{host} invites {guest} and # other people to his party.}}}'
              ],
            ],
            null,
          )
        ],
        [
          'other',
          Plural.from(
            'num_guests',
            [
              ['=0', '{{host} does not give a party.}'],
              ['=1', '{{host} invites {guest} to their party.}'],
              [
                '=2',
                '{{host} invites {guest} and one other person to their party.}'
              ],
              [
                'other',
                '{{host} invites {guest} and # other people to their party.}}}'
              ],
            ],
            null,
          )
        ],
      ],
      null,
    );
    print(expectedMessage);
    expect(
      parsedMessage,
      expectedMessage,
    );
  });
}
