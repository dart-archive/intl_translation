// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.10

// ignore_for_file: avoid_dynamic_calls

/// Contains a parser for ICU format plural/gender/select format for localized
/// messages. See extract_to_arb.dart and make_hardcoded_translation.dart.
library icu_parser;

import 'package:intl_translation/src/intl_message.dart';

/// This defines a grammar for ICU MessageFormat syntax. Usage is
///       new IcuParser.message.parse().value;
/// The "parse" method will return a Success or Failure object which responds
/// to "value".
class Parser {
  final dynamic result;
  final int end;

  Parser(this.result, this.end);

  Parser extract(int index) {
    if (result is List) {
      List resultList = result as List;
      return Parser(resultList[index], end);
    }
    throw Exception('May only be called on a List');
  }

  Parser pick(List<int> indices) {
    if (result is List) {
      List resultList = result as List;
      if (indices.length > 1) {
        return Parser(indices.map((index) => resultList[index]).toList(), end);
      }
    }
    throw Exception('May only be called on a List');
  }

  Parser mapResult(dynamic Function(dynamic res) callable) =>
      Parser(callable(result), end);

  Message toMessage() => Message.from(result, null);
}

class IcuParser {
  final String input;

  Parser char(int at, String t) =>
      input.startsWith(t, at) ? Parser(t, at + t.length) : null;

  Parser plus(Parser Function(int s) callable, int at) {
    int newAt = -1;
    List<Parser> results = [];
    while (newAt != at) {
      newAt = at;
      var parser = callable(newAt);
      if (parser != null) {
        at = parser.end;
        results.add(parser);
      }
    }
    return results.isNotEmpty
        ? Parser(results.map((parser) => parser.result).toList(), newAt)
        : null;
  }

  Parser and(List<Parser Function(int s)> callables, int at) {
    int newAt = at;
    List<Parser> resParser = [];
    for (int i = 0; i < callables.length; i++) {
      var callable = callables[i];
      Parser parser = callable.call(newAt);
      if (parser != null) {
        resParser.add(parser);
        newAt = parser.end;
      } else {
        return null;
      }
    }
    return Parser(resParser.map((p) => p.result).toList(), newAt);
  }

  Parser asKeywords(List keywords, int at) {
    for (var keyword in keywords) {
      var match = RegExp('\\s*$keyword\\s*').matchAsPrefix(input, at);
      if (match != null) {
        return Parser(keyword, match.end);
      }
    }
    return null;
  }

  Parser trimStart(int at) {
    return Parser(input, RegExp(r'\s*').matchAsPrefix(input, at).end);
  }

  Parser openCurly(int at) => char(at, '{');
  Parser closeCurly(int at) => char(at, '}');

  Parser icuEscapedText(int at) {
    Match match = RegExp(r"'({)'").matchAsPrefix(input, at) ??
        RegExp(r"'(})'").matchAsPrefix(input, at) ??
        RegExp(r"'(')").matchAsPrefix(input, at);
    return match != null ? Parser(match?.group(1), match.end) : null;
  }

  Parser icuText(int at) =>
      at < input.length && RegExp(r'[^\{\}\<]').matchAsPrefix(input, at) != null
          ? Parser(input[at], at + 1)
          : null;

  Parser messageText(int at) => plus((s) => icuEscapedText(s) ?? icuText(s), at)
      ?.mapResult((res) => res.map((r) => r as String)?.join());

  Parser nonIcuMessageText(int at) {
    if (at < input.length) {
      var match = RegExp(r'[^\{]+').matchAsPrefix(input, at);
      if (match != null) {
        return Parser(match.group(0), match.end);
      }
    }
    return null;
  }

  Parser number(int at) {
    Match match = RegExp(r'\s*([0-9]+)\s*').matchAsPrefix(input, at);
    return match != null
        ? Parser(int.parse(match.group(1)).toString(), match.end)
        : null;
  }

  Parser id(int at) {
    Match match =
        RegExp(r'\s*([a-zA-Z][a-zA-Z_0-9]*)\s*').matchAsPrefix(input, at);
    return match != null ? Parser(match.group(1), match.end) : null;
  }

  Parser comma(int at) {
    Match match = RegExp(r'\s*(,)\s*').matchAsPrefix(input, at);
    return match != null ? Parser(',', match.end) : null;
  }

  static const List pluralKeywords = [
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
  static const List genderKeywords = ['female', 'male', 'other'];

  Parser genderKeyword(int at) => asKeywords(genderKeywords, at);

  Parser pluralKeyword(int at) => asKeywords(pluralKeywords, at);

  Parser interiorText(int at) => plus((s) => contents(s), at) ?? empty(at);

  Parser preface(int at) => and(
        [
          (s) => openCurly(s),
          (s) => id(s),
          (s) => comma(s),
        ],
        at,
      )?.extract(1);

  Parser pluralLiteral(int at) => char(at, 'plural');
  Parser selectLiteral(int at) => char(at, 'select');

  Parser pluralClause(int at) => and(
        [
          (s) => trimStart(s),
          (s) => pluralKeyword(s),
          (s) => openCurly(s),
          (s) => interiorText(s),
          (s) => closeCurly(s),
          (s) => trimStart(s),
        ],
        at,
      )?.pick([1, 3]);

  Parser plural(int at) => and([
        (s) => preface(s),
        (s) => pluralLiteral(s),
        (s) => comma(s),
        (s) => plus((s1) => pluralClause(s1), s),
        (s) => closeCurly(s),
      ], at);

  Parser intlPlural(int at) => plural(at)?.mapResult(
      (parsers) => Plural.from(parsers[0] as String, parsers[3], null));

  Parser genderClause(int at) => plus(
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
          )?.pick([1, 3]),
      at);

  Parser gender(int at) => and([
        (s) => preface(s),
        (s) => selectLiteral(s),
        (s) => comma(s),
        (s) => genderClause(s),
        (s) => closeCurly(s),
      ], at);

  Parser intlGender(int at) => gender(at)?.mapResult(
        (values) => Gender.from(values.first, values[3], null),
      );

  Parser selectClause(int at) => plus(
      (s1) => and([
            (s) => id(s),
            (s) => openCurly(s),
            (s) => interiorText(s),
            (s) => closeCurly(s),
          ], s1)
              ?.pick([0, 2]),
      at);

  Parser select(int at) => and([
        (s) => preface(s),
        (s) => selectLiteral(s),
        (s) => comma(s),
        (s) => selectClause(s),
        (s) => closeCurly(s),
      ], at);

  Parser intlSelect(int at) => select(at)
      ?.mapResult((values) => Select.from(values.first, values[3], null));

  Parser pluralOrGenderOrSelect(int at) =>
      (intlPlural(at) ?? intlGender(at)) ?? intlSelect(at);

  Parser contents(int at) =>
      (pluralOrGenderOrSelect(at) ?? parameter(at)) ?? messageText(at);

  Parser simpleText(int at) => plus(
        (s) => (nonIcuMessageText(s) ?? parameter(s)) ?? openCurly(s),
        at,
      );

  Parser empty(int at) => Parser('', at);

  Parser parameter(int at) => and([
        (s) => openCurly(s),
        (s) => id(s),
        (s) => closeCurly(s),
      ], at)
          ?.mapResult((result) => VariableSubstitution.named(result[1], null));

  /// The primary entry point for parsing. Accepts a string and produces
  /// a parsed representation of it as a Message.
  Message message(int at) =>
      (pluralOrGenderOrSelect(at) ?? empty(at))?.toMessage();

  /// Represents an ordinary message, i.e. not a plural/gender/select, although
  /// it may have parameters.
  Message nonIcuMessage(int at) => (simpleText(at) ?? empty(at))?.toMessage();

  Message stuff(int at) =>
      Message.from(pluralOrGenderOrSelect(at) ?? empty(at), null);

  IcuParser(this.input);

  Message pluralAndGenderParse() =>
      (pluralOrGenderOrSelect(0) ?? empty(0)).toMessage();

  Message nonIcuMessageParse() => nonIcuMessage(0);
}
