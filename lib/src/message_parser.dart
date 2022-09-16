// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.10

// ignore_for_file: avoid_dynamic_calls

/// Contains a parser for ICU format plural/gender/select format for localized
/// messages. See extract_to_arb.dart and make_hardcoded_translation.dart.
library message_parser;

import 'package:intl_translation/src/intl_message.dart';

class MessageParser {
  final _ParserUtil _parser;

  MessageParser(String input) : _parser = _ParserUtil(input);

  Message pluralAndGenderParse() => Message.from(
        (_parser.pluralOrGenderOrSelect(0) ?? _parser.empty(0)).result,
        null,
      );

  Message nonIcuMessageParse() => Message.from(
        (_parser.simpleText(0) ?? _parser.empty(0)).result,
        null,
      );
}

///Holds a parsed piece of the input
class Parsed<T> {
  ///The result of parsing this piece of the message
  final T result;

  ///The position of the parser after parsing this piece of the message
  final int at;

  Parsed(this.result, this.at);

  ///Helper method to simplify null checks
  Parsed<S> mapResult<S>(S Function(T res) callable) =>
      Parsed<S>(callable(result), at);
}

///Methods for actually parsing a message. The parser goes through the message
///in a DFS kind of way. Whenever a branch fails to parse, it returns null.
class _ParserUtil {
  final String input;
  const _ParserUtil(this.input);

  static RegExp quotedBracketOpen = RegExp(r"'({)'");
  static RegExp quotedBracketClose = RegExp(r"'(})'");
  static RegExp doubleQuotes = RegExp(r"'(')");
  static RegExp numberRegex = RegExp(r'\s*([0-9]+)\s*');
  static RegExp nonICURegex = RegExp(r'[^\{\}\<]');
  static RegExp idRegex = RegExp(r'\s*([a-zA-Z][a-zA-Z_0-9]*)\s*');
  static RegExp nonOpenBracketRegex = RegExp(r'[^\{]+');
  static RegExp commaWithWhitespace = RegExp(r'\s*(,)\s*');
  static List<String> pluralKeywords = [
    '=0',
    '=1',
    '=2',
    'zero',
    'one',
    'two',
    'few',
    'many',
    'other'
  ];
  static Map<String, RegExp> pluralKeywordsToRegex = {
    for (var v in pluralKeywords) v: RegExp('\\s*$v\\s*')
  };
  static List<String> genderKeywords = ['female', 'male', 'other'];
  static Map<String, RegExp> genderKeywordsToRegex = {
    for (var v in genderKeywords) v: RegExp('\\s*$v\\s*')
  };

  ///Corresponds to a [+] operator in a regex, matching at least one occurence
  ///of the [callable].
  static Parsed<List<T>> oneOrMore<T>(
    Parsed<T> Function(int s) callable,
    int at,
  ) {
    int newAt = -1;
    List<Parsed<T>> results = [];
    while (newAt != at) {
      newAt = at;
      Parsed<T> parser = callable(newAt);
      if (parser != null) {
        at = parser.at;
        results.add(parser);
      }
    }
    return results.isNotEmpty
        ? Parsed<List<T>>(results.map((p) => p.result).toList(), newAt)
        : null;
  }

  ///Corresponds to an [AND] operator, matching all [callables] or failing, i.e.
  ///returning [null].
  static Parsed<List<T>> and<T>(
    List<Parsed<T> Function(int s)> callables,
    int at,
  ) {
    int newAt = at;
    List<Parsed<T>> resParser = [];
    for (int i = 0; i < callables.length; i++) {
      var callable = callables[i];
      Parsed<T> parser = callable.call(newAt);
      if (parser != null) {
        resParser.add(parser);
        newAt = parser.at;
      } else {
        return null;
      }
    }
    return Parsed<List<T>>(resParser.map((p) => p.result).toList(), newAt);
  }

  ///Match a simple string
  Parsed<String> matchString(int at, String t) =>
      input.startsWith(t, at) ? Parsed(t, at + t.length) : null;

  ///Match any of the given keywords
  Parsed<String> asKeywords(Map<String, RegExp> keywordsToRegex, int at) {
    if (at < input.length) {
      for (var entry in keywordsToRegex.entries) {
        var match = entry.value.matchAsPrefix(input, at);
        if (match != null) {
          return Parsed<String>(entry.key, match.end);
        }
      }
    }
    return null;
  }

  ///Parse whitespace
  Parsed<String> trimAt(int at) => at < input.length
      ? Parsed<String>(input, RegExp(r'\s*').matchAsPrefix(input, at).end)
      : null;

  Parsed<String> openCurly(int at) => matchString(at, '{');
  Parsed<String> closeCurly(int at) => matchString(at, '}');

  Parsed<String> icuEscapedText(int at) {
    if (at < input.length) {
      Match match = quotedBracketOpen.matchAsPrefix(input, at) ??
          quotedBracketClose.matchAsPrefix(input, at) ??
          doubleQuotes.matchAsPrefix(input, at);
      return match != null ? Parsed<String>(match?.group(1), match.end) : null;
    }
    return null;
  }

  Parsed<String> icuText(int at) =>
      at < input.length && nonICURegex.matchAsPrefix(input, at) != null
          ? Parsed<String>(input[at], at + 1)
          : null;

  Parsed<String> messageText(int at) =>
      oneOrMore<String>((s) => icuEscapedText(s) ?? icuText(s), at)
          ?.mapResult<String>((res) => res?.join());

  Parsed<String> nonIcuMessageText(int at) {
    if (at < input.length) {
      Match match = nonOpenBracketRegex.matchAsPrefix(input, at);
      if (match != null) {
        return Parsed<String>(match.group(0), match.end);
      }
    }
    return null;
  }

  Parsed<String> number(int at) {
    Match match = numberRegex.matchAsPrefix(input, at);
    return match != null
        ? Parsed(int.parse(match.group(1)).toString(), match.end)
        : null;
  }

  Parsed<String> id(int at) {
    if (at < input.length) {
      Match match = idRegex.matchAsPrefix(input, at);
      return match != null ? Parsed(match.group(1), match.end) : null;
    }
    return null;
  }

  Parsed<String> comma(int at) =>
      at < input.length && commaWithWhitespace.matchAsPrefix(input, at) != null
          ? Parsed(',', at + 1)
          : null;

  Parsed<String> preface(int at) => and<String>(
        [
          (s) => openCurly(s),
          (s) => id(s),
          (s) => comma(s),
        ],
        at,
      )?.mapResult<String>((res) => res[1]);

  Parsed<List<dynamic>> pluralClause(int at) => and<dynamic>(
        [
          (s) => trimAt(s),
          (s) => asKeywords(_ParserUtil.pluralKeywordsToRegex, s),
          (s) => openCurly(s),
          (s) => interiorText(s),
          (s) => closeCurly(s),
          (s) => trimAt(s),
        ],
        at,
      )?.mapResult((res) => [res[1], res[3]]);

  Parsed<List<dynamic>> plural(int at) => and(
        [
          (s) => preface(s),
          (s) => matchString(s, 'plural'),
          (s) => comma(s),
          (s) => oneOrMore((s1) => pluralClause(s1), s),
          (s) => closeCurly(s),
        ],
        at,
      );

  Parsed<Message> intlPlural(int at) =>
      plural(at)?.mapResult((parsers) => Plural.from(
            parsers[0] as String,
            parsers[3],
            null,
          ));

  Parsed<String> genderKeyword(int at) => asKeywords(genderKeywordsToRegex, at);

  Parsed<List<dynamic>> genderClause(int at) => oneOrMore(
        (s1) => and(
          [
            (s) => trimAt(s),
            (s) => genderKeyword(s),
            (s) => openCurly(s),
            (s) => interiorText(s),
            (s) => closeCurly(s),
            (s) => trimAt(s),
          ],
          s1,
        )?.mapResult((res) => [res[1], res[3]]),
        at,
      );

  Parsed<List<dynamic>> gender(int at) => and(
        [
          (s) => preface(s),
          (s) => selectLiteral(s),
          (s) => comma(s),
          (s) => genderClause(s),
          (s) => closeCurly(s),
        ],
        at,
      );

  Parsed<Message> intlGender(int at) => gender(at)
      ?.mapResult((values) => Gender.from(values.first, values[3], null));

  Parsed<String> selectLiteral(int at) => matchString(at, 'select');

  Parsed<List<dynamic>> selectClause(int at) => oneOrMore(
        (s1) => and([
          (s) => id(s),
          (s) => openCurly(s),
          (s) => interiorText(s),
          (s) => closeCurly(s),
        ], s1)
            ?.mapResult((res) => [res[0], res[2]]),
        at,
      );

  Parsed<List<dynamic>> select(int at) => and(
        [
          (s) => preface(s),
          (s) => selectLiteral(s),
          (s) => comma(s),
          (s) => selectClause(s),
          (s) => closeCurly(s),
        ],
        at,
      );

  Parsed<Message> intlSelect(int at) => select(at)
      ?.mapResult((values) => Select.from(values.first, values[3], null));

  Parsed<Message> pluralOrGenderOrSelect(int at) =>
      (intlPlural(at) ?? intlGender(at)) ?? intlSelect(at);

  Parsed<dynamic> contents(int at) =>
      (pluralOrGenderOrSelect(at) ?? parameter(at)) ?? messageText(at);

  Parsed interiorText(int at) => oneOrMore((s) => contents(s), at) ?? empty(at);

  Parsed<dynamic> simpleText(int at) => oneOrMore(
        (s) => (nonIcuMessageText(s) ?? parameter(s)) ?? openCurly(s),
        at,
      );

  Parsed<String> empty(int at) => Parsed<String>('', at);

  Parsed<Message> parameter(int at) => and(
        [
          (s) => openCurly(s),
          (s) => id(s),
          (s) => closeCurly(s),
        ],
        at,
      )?.mapResult((result) => VariableSubstitution.named(result[1], null));
}
