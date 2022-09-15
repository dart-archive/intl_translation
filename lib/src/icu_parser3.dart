// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.10

// ignore_for_file: avoid_dynamic_calls

/// Contains a parser for ICU format plural/gender/select format for localized
/// messages. See extract_to_arb.dart and make_hardcoded_translation.dart.
library icu_parser;

import 'package:intl_translation/src/intl_message.dart';
import 'package:petitparser/petitparser.dart';
import 'package:intl_translation/src/icu_parser.dart' as oldparser;

/// This defines a grammar for ICU MessageFormat syntax. Usage is
///       new IcuParser.message.parse().value;
/// The "parse" method will return a Success or Failure object which responds
/// to "value".
class Parser {
  final dynamic result;
  final int end;

  Parser(this.result, this.end);

  Parser extract(List<int> indices) {
    if (result is List) {
      List resultList = result as List;
      if (indices.length > 1) {
        return Parser(indices.map((index) => resultList[index]).toList(), end);
      } else if (indices.length == 1) {
        return Parser(resultList[indices[0]], end);
      }
    }
    throw Exception('Wrong type or args given');
  }

  R map<R>(R Function(dynamic res, int end) callable) => callable(result, end);

  @override
  String toString() {
    return result.toString();
  }
}

class IcuParser {
  final String input;

  Parser char(int at, String t) =>
      t.length + at <= input.length && input.startsWith(t, at)
          ? Parser(t, at + t.length)
          : null;
  Parser neg(int at, Parser Function(int s) callable) =>
      at < input.length && callable(at) == null
          ? Parser(input[at], at + 1)
          : null;

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

  Parser quotedCurly(int at) {
    var openBr = char(at, "'{'");
    if (openBr != null) return Parser('{', openBr.end);
    var closedBr = char(at, "'}'");
    if (closedBr != null) return Parser('{', closedBr.end);
    return null;
  }

  Parser icuEscapedText(int at) => quotedCurly(at) ?? twoSingleQuotes(at);
  Parser curly(int at) => openCurly(at) ?? closeCurly(at);
  Parser notAllowedInIcuText(int at) => curly(at) ?? char(at, '<');

  Parser icuText(int at) => neg(at, (s) => notAllowedInIcuText(s));

  Parser notAllowedInNormalText(int at) => char(at, '{');

  Parser normalText(int at) => neg(at, (s) => notAllowedInNormalText(s));

  Parser messageText(int at) {
    var plus2 = plus((s) => icuEscapedText(s) ?? icuText(s), at);
    return plus2 != null
        ? Parser(plus2.result?.map((r) => r as String)?.join(), plus2.end)
        : null;
  }

  Parser nonIcuMessageText(int at) =>
      plus((s) => normalText(s), at)?.map((res, end) => Parser(
            res.reduce((e1, e2) => e1.toString() + e2.toString()),
            end,
          ));

  Parser twoSingleQuotes(int at) {
    Parser char2 = char(at, "''");
    if (char2 != null) {
      return Parser("'", char2.end);
    } else {
      return null;
    }
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
    return match != null ? Parser(match.group(1), match.end) : null;
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

  Parser interiorText(int at) =>
      plus((s) => contents(s), at) ?? empty(at); //TODO

  Parser preface(int at) => and(
        [
          (s) => openCurly(s),
          (s) => id(s),
          (s) => comma(s),
        ],
        at,
      )?.extract([1]);

  Parser pluralLiteral(int at) => char(at, 'plural');

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
      )?.extract([1, 3]);

  Parser plural(int at) => and([
        (s) => preface(s),
        (s) => pluralLiteral(s),
        (s) => comma(s),
        (s) => plus((s1) => pluralClause(s1), s),
        (s) => closeCurly(s),
      ], at);

  Parser intlPlural(int at) => plural(at)?.map((parsers, end) => Parser(
        Plural.from(parsers[0].toString(), parsers[3], null),
        end,
      ));

  Parser selectLiteral(int at) =>
      char(at, 'select'); //does plural work the same way as char?

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
          )?.extract([1, 3]),
      at);

  Parser gender(int at) => and([
        (s) => preface(s),
        (s) => selectLiteral(s),
        (s) => comma(s),
        (s) => genderClause(s),
        (s) => closeCurly(s),
      ], at);

  Parser intlGender(int at) => gender(at)?.map((values, end) => Parser(
        Gender.from(values.first, values[3], null),
        end,
      ));

  Parser selectClause(int at) => plus(
      (s1) => and([
            (s) => id(s),
            (s) => openCurly(s),
            (s) => interiorText(s),
            (s) => closeCurly(s),
          ], s1)
              ?.extract([0, 2]),
      at);

  Parser generalSelect(int at) => and([
        (s) => preface(s),
        (s) => selectLiteral(s),
        (s) => comma(s),
        (s) => selectClause(s),
        (s) => closeCurly(s),
      ], at);

  Parser intlSelect(int at) => generalSelect(at)?.map((values, end) => Parser(
        Select.from(values.first, values[3], null),
        end,
      ));

  Parser pluralOrGenderOrSelect(int at) =>
      (intlPlural(at) ?? intlGender(at)) ?? intlSelect(at);

  dynamic contents(int at) =>
      (pluralOrGenderOrSelect(at) ?? parameter(at)) ?? messageText(at);

  Parser simpleText(int at) => plus(
        (s) => (nonIcuMessageText(s) ?? parameter(s)) ?? openCurly(s),
        at,
      );

  Parser empty(int at) => Parser('', at);

  Parser parameter(int at) {
    Parser and2 = and([
      (s) => openCurly(s),
      (s) => id(s),
      (s) => closeCurly(s),
    ], at);
    return and2?.map((result, end) => Parser(
          VariableSubstitution.named(result[1], null),
          end,
        ));
  }

  /// The primary entry point for parsing. Accepts a string and produces
  /// a parsed representation of it as a Message.
  Message message(int at) => (pluralOrGenderOrSelect(at) ?? empty(at))
      ?.map((r, _) => Message.from(r, null));

  /// Represents an ordinary message, i.e. not a plural/gender/select, although
  /// it may have parameters.
  Message nonIcuMessage(int at) =>
      (simpleText(at) ?? empty(at))?.map((r, _) => Message.from(r, null));

  Message stuff(int at) =>
      Message.from(pluralOrGenderOrSelect(at) ?? empty(at), null);

  IcuParser(this.input);

  Message pluralAndGenderParse() => (pluralOrGenderOrSelect(0) ?? empty(0))
      .map((res, end) => Message.from(res, null));

  Message nonIcuMessageParse() => nonIcuMessage(0);
}

void main(List args) {
  testNonIcu();
}

void testChar() {
  var input = 'abc';
  var char2 = 't';
  var parser = IcuParser(input).char(0, char2);
  print(parser?.result);
  var parse = char(char2).parse(input);
  print(parse);
}

void testNumber() {
  var input = '   023213123   ';
  var parser = IcuParser(input).number(0);
  print(parser?.result);
  var parse = oldparser.IcuParser().number.parse(input);
  print(parse);
}

void testId() {
  var input = '  dsadas_das_sadas___dsadas  ';
  var parser = IcuParser(input).id(0);
  print('${parser?.result}//');
  var parse = oldparser.IcuParser().id.parse(input);
  print('${parse.value}//');
}

void testKeywords() {
  var input = 'female';
  var parser = IcuParser(input).genderKeyword(0);
  print('${parser?.result}//');
  var parse = oldparser.IcuParser().genderKeyword.parse(input);
  print('${parse.value}//');
}

void testPreface() {
  var input = '{test_name ,  ';
  var parse = oldparser.IcuParser().preface.parse(input);
  print('${parse.value}//');
  var parser = IcuParser(input).preface(0);
  print('${parser?.result}//');
}

void testInterior() {
  var input = 'interior';
  var parse = oldparser.IcuParser().interiorText.parse(input);
  print('${parse.value}//');
  var parser = IcuParser(input).interiorText(0);
  print('${parser.result}//');
}

void testPluralKeyword() {
  var input = '  =0  ';
  var parse = oldparser.IcuParser().pluralKeyword.parse(input);
  print('${parse.value}//');
  var parser = IcuParser(input).pluralKeyword(0);
  print('${parser.result}//');
}

void testPluralClause() {
  var input = '  =0  {interior}  ';
  var parse = oldparser.IcuParser().pluralClause.parse(input);
  print('${parse.value}//');
  var parser = IcuParser(input).pluralClause(0);
  print('${parser.result}//');
}

void testIntlPlural() {
  var input = '{test_name , plural , one{interior} }';
  var parse = oldparser.IcuParser().intlPlural.parse(input);
  print('${parse.value}//');
  var parser = IcuParser(input).intlPlural(0);
  print('${parser}//');
}

void testNonIcu() {
  var input = r'''fr
Il s'agit d'un message
Un autre message avec un seul paramètre {x}
Cette message prend plusiers lignes.
interessant (fr): '<>{}= +-_$()&^%$#@!~`'
{a}, {b}, {c}
Cette chaîne est toujours traduit
L'interpolation est délicate quand elle se termine une phrase comme {s}.''';
  var parse = oldparser.IcuParser().nonIcuMessage.parse(input);
  print(parse.value);
  var parser = IcuParser(input).nonIcuMessage(0);
  print(parser);
}
