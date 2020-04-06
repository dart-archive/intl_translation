// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Contains a parser for ICU format plural/gender/select format for localized
/// messages. See extract_to_arb.dart and make_hardcoded_translation.dart.
library icu_parser;

import 'package:intl_translation/src/intl_message.dart';
import 'package:petitparser/petitparser.dart';

/// This defines a grammar for ICU MessageFormat syntax. Usage is
///       new IcuParser.message.parse(<string>).value;
/// The "parse" method will return a Success or Failure object which responds
/// to "value".
class IcuParser {
  Parser get openCurly => char('{');

  Parser get closeCurly => char('}');
  Parser get quotedCurly => (string("'{'") | string("'}'")).map((x) => x[1]);

  Parser get icuEscapedText => quotedCurly | twoSingleQuotes;
  Parser get curly => (openCurly | closeCurly);
  Parser get notAllowedInIcuText => curly | char('<');
  Parser get icuText => notAllowedInIcuText.neg();
  Parser get notAllowedInNormalText => char('{');
  Parser get normalText => notAllowedInNormalText.neg();
  Parser get messageText =>
      (icuEscapedText | icuText).plus().map((x) => x.join());
  Parser get nonIcuMessageText => normalText.plus().map((x) => x.join());
  Parser get twoSingleQuotes => string("''").map((x) => "'");
  Parser get number => digit().plus().flatten().trim().map(int.parse);
  Parser get id => (letter() & (word() | char('_')).star()).flatten().trim();
  Parser get comma => char(',').trim();

  /// Given a list of possible keywords, return a rule that accepts any of them.
  /// e.g., given ["male", "female", "other"], accept any of them.
  Parser asKeywords(List<String> list) =>
      list.map(string).cast<Parser>().reduce((a, b) => a | b).flatten().trim();

  Parser get pluralKeyword => asKeywords(
      ['=0', '=1', '=2', 'zero', 'one', 'two', 'few', 'many', 'other']);
  Parser get genderKeyword => asKeywords(['female', 'male', 'other']);

  var interiorText = undefined();

  Parser get preface => (openCurly & id & comma).map((values) => values[1]);

  Parser get pluralLiteral => string('plural');
  Parser get pluralClause =>
      (pluralKeyword & openCurly & interiorText & closeCurly)
          .trim()
          .map((result) => [result[0], result[2]]);
  Parser get plural =>
      preface & pluralLiteral & comma & pluralClause.plus() & closeCurly;
  Parser get intlPlural =>
      plural.map((values) => Plural.from(values.first, values[3], null));

  Parser get selectLiteral => string('select');
  Parser get genderClause =>
      (genderKeyword & openCurly & interiorText & closeCurly)
          .trim()
          .map((result) => [result[0], result[2]]);
  Parser get gender =>
      preface & selectLiteral & comma & genderClause.plus() & closeCurly;
  Parser get intlGender =>
      gender.map((values) => Gender.from(values.first, values[3], null));
  Parser get selectClause =>
      (id & openCurly & interiorText & closeCurly).map((x) => [x.first, x[2]]);
  Parser get generalSelect =>
      preface & selectLiteral & comma & selectClause.plus() & closeCurly;
  Parser get intlSelect =>
      generalSelect.map((values) => Select.from(values.first, values[3], null));

  Parser get pluralOrGenderOrSelect => intlPlural | intlGender | intlSelect;

  Parser get contents => pluralOrGenderOrSelect | parameter | messageText;
  Parser get simpleText => (nonIcuMessageText | parameter | openCurly).plus();
  Parser get empty => epsilon().map((_) => '');

  Parser get parameter => (openCurly & id & closeCurly)
      .map((param) => VariableSubstitution.named(param[1], null));

  /// The primary entry point for parsing. Accepts a string and produces
  /// a parsed representation of it as a Message.
  Parser get message => (pluralOrGenderOrSelect | empty)
      .map((chunk) => Message.from(chunk, null));

  /// Represents an ordinary message, i.e. not a plural/gender/select, although
  /// it may have parameters.
  Parser get nonIcuMessage =>
      (simpleText | empty).map((chunk) => Message.from(chunk, null));

  Parser get stuff => (pluralOrGenderOrSelect | empty)
      .map((chunk) => Message.from(chunk, null));

  IcuParser() {
    // There is a cycle here, so we need the explicit set to avoid
    // infinite recursion.
    interiorText.set(contents.plus() | empty);
  }
}
