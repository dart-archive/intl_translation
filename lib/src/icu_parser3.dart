// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.10

// ignore_for_file: avoid_dynamic_calls

/// Contains a parser for ICU format plural/gender/select format for localized
/// messages. See extract_to_arb.dart and make_hardcoded_translation.dart.
library icu_parser;

import 'package:intl_translation/src/intl_message.dart';

class IcuMessageParser {
  final _IcuParser _parser;

  IcuMessageParser(String input) : _parser = _IcuParser(input);

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
class Parser<T> {
  final T result;
  final int end;

  Parser(this.result, this.end);

  Parser<S> mapResult<S>(S Function(T res) callable) =>
      Parser<S>(callable(result), end);
}

class _IcuParser {
  final String input;
  const _IcuParser(this.input);

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

  Parser<String> matchString(int at, String t) =>
      input.startsWith(t, at) ? Parser(t, at + t.length) : null;

  Parser<List<S>> oneOrMore<S>(Parser<S> Function(int s) callable, int at) {
    int newAt = -1;
    List<Parser<S>> results = [];
    while (newAt != at) {
      newAt = at;
      Parser<S> parser = callable(newAt);
      if (parser != null) {
        at = parser.end;
        results.add(parser);
      }
    }
    return results.isNotEmpty
        ? Parser<List<S>>(results.map((p) => p.result).toList(), newAt)
        : null;
  }

  Parser<List<S>> and<S>(List<Parser<S> Function(int s)> callables, int at) {
    int newAt = at;
    List<Parser<S>> resParser = [];
    for (int i = 0; i < callables.length; i++) {
      var callable = callables[i];
      Parser<S> parser = callable.call(newAt);
      if (parser != null) {
        resParser.add(parser);
        newAt = parser.end;
      } else {
        return null;
      }
    }
    return Parser<List<S>>(resParser.map((p) => p.result).toList(), newAt);
  }

  Parser<String> asKeywords(Map<String, RegExp> keywordsToRegex, int at) {
    if (at < input.length) {
      for (var entry in keywordsToRegex.entries) {
        var match = entry.value.matchAsPrefix(input, at);
        if (match != null) {
          return Parser<String>(entry.key, match.end);
        }
      }
    }
    return null;
  }

  Parser<String> trimStart(int at) => at < input.length
      ? Parser<String>(input, RegExp(r'\s*').matchAsPrefix(input, at).end)
      : null;

  Parser<String> openCurly(int at) => matchString(at, '{');
  Parser<String> closeCurly(int at) => matchString(at, '}');

  Parser<String> icuEscapedText(int at) {
    if (at < input.length) {
      Match match = quotedBracketOpen.matchAsPrefix(input, at) ??
          quotedBracketClose.matchAsPrefix(input, at) ??
          doubleQuotes.matchAsPrefix(input, at);
      return match != null ? Parser<String>(match?.group(1), match.end) : null;
    }
    return null;
  }

  Parser<String> icuText(int at) =>
      at < input.length && nonICURegex.matchAsPrefix(input, at) != null
          ? Parser<String>(input[at], at + 1)
          : null;

  Parser<String> messageText(int at) =>
      oneOrMore<String>((s) => icuEscapedText(s) ?? icuText(s), at)
          ?.mapResult<String>((res) => res?.join());

  Parser<String> nonIcuMessageText(int at) {
    if (at < input.length) {
      Match match = nonOpenBracketRegex.matchAsPrefix(input, at);
      if (match != null) {
        return Parser<String>(match.group(0), match.end);
      }
    }
    return null;
  }

  Parser<String> number(int at) {
    Match match = numberRegex.matchAsPrefix(input, at);
    return match != null
        ? Parser(int.parse(match.group(1)).toString(), match.end)
        : null;
  }

  Parser<String> id(int at) {
    if (at < input.length) {
      Match match = idRegex.matchAsPrefix(input, at);
      return match != null ? Parser(match.group(1), match.end) : null;
    }
    return null;
  }

  Parser<String> comma(int at) =>
      at < input.length && commaWithWhitespace.matchAsPrefix(input, at) != null
          ? Parser(',', at + 1)
          : null;

  Parser<String> preface(int at) => and<String>(
        [
          (s) => openCurly(s),
          (s) => id(s),
          (s) => comma(s),
        ],
        at,
      )?.mapResult<String>((res) => res[1]);

  Parser<List<dynamic>> pluralClause(int at) => and<dynamic>(
        [
          (s) => trimStart(s),
          (s) => asKeywords(_IcuParser.pluralKeywordsToRegex, s),
          (s) => openCurly(s),
          (s) => interiorText(s),
          (s) => closeCurly(s),
          (s) => trimStart(s),
        ],
        at,
      )?.mapResult((res) => [res[1], res[3]]);

  Parser<List<dynamic>> plural(int at) => and(
        [
          (s) => preface(s),
          (s) => matchString(s, 'plural'),
          (s) => comma(s),
          (s) => oneOrMore((s1) => pluralClause(s1), s),
          (s) => closeCurly(s),
        ],
        at,
      );

  Parser<Message> intlPlural(int at) =>
      plural(at)?.mapResult((parsers) => Plural.from(
            parsers[0] as String,
            parsers[3],
            null,
          ));

  Parser<String> genderKeyword(int at) => asKeywords(genderKeywordsToRegex, at);

  Parser<List<dynamic>> genderClause(int at) => oneOrMore(
        (s1) => and(
          [
            (s) => trimStart(s),
            (s) => genderKeyword(s),
            (s) => openCurly(s),
            (s) => interiorText(s),
            (s) => closeCurly(s),
            (s) => trimStart(s),
          ],
          s1,
        )?.mapResult((res) => [res[1], res[3]]),
        at,
      );

  Parser<List<dynamic>> gender(int at) => and(
        [
          (s) => preface(s),
          (s) => selectLiteral(s),
          (s) => comma(s),
          (s) => genderClause(s),
          (s) => closeCurly(s),
        ],
        at,
      );

  Parser<Message> intlGender(int at) => gender(at)
      ?.mapResult((values) => Gender.from(values.first, values[3], null));

  Parser<String> selectLiteral(int at) => matchString(at, 'select');

  Parser<List<dynamic>> selectClause(int at) => oneOrMore(
        (s1) => and([
          (s) => id(s),
          (s) => openCurly(s),
          (s) => interiorText(s),
          (s) => closeCurly(s),
        ], s1)
            ?.mapResult((res) => [res[0], res[2]]),
        at,
      );

  Parser<List<dynamic>> select(int at) => and(
        [
          (s) => preface(s),
          (s) => selectLiteral(s),
          (s) => comma(s),
          (s) => selectClause(s),
          (s) => closeCurly(s),
        ],
        at,
      );

  Parser<Message> intlSelect(int at) => select(at)
      ?.mapResult((values) => Select.from(values.first, values[3], null));

  Parser<Message> pluralOrGenderOrSelect(int at) =>
      (intlPlural(at) ?? intlGender(at)) ?? intlSelect(at);

  Parser<dynamic> contents(int at) =>
      (pluralOrGenderOrSelect(at) ?? parameter(at)) ?? messageText(at);

  Parser interiorText(int at) => oneOrMore((s) => contents(s), at) ?? empty(at);

  Parser<dynamic> simpleText(int at) => oneOrMore(
        (s) => (nonIcuMessageText(s) ?? parameter(s)) ?? openCurly(s),
        at,
      );

  Parser<String> empty(int at) => Parser<String>('', at);

  Parser<Message> parameter(int at) => and(
        [
          (s) => openCurly(s),
          (s) => id(s),
          (s) => closeCurly(s),
        ],
        at,
      )?.mapResult((result) => VariableSubstitution.named(result[1], null));
}
