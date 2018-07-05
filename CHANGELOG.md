## 0.16.8
  * Allow message extraction to find messages from prefixed uses of Intl.
  * Move analyzer dependency up to 0.33.0

## 0.16.7
  * Allow message extraction to find messages in class field declarations
    and top-level declarations.
  * Fix incorrect name and parameters propagation during extraction phase.
  * Still more uppercase constant removal.

## 0.16.6
  * More uppercase constant removal.

## 0.16.5
  * Replace uses of JSON constant for Dart 2 compatibility.

## 0.16.4
  * Update Intl compatibility requirements. This requires at least 0.15.3 of
    Intl, because the tests contain messages with the new "skip" parameter.

## 0.16.3
  * Fix https://github.com/flutter/flutter/issues/15458 - specify concrete type
    for generated map.

## 0.16.2
 * Handle fallback better when we provide translations for locale "xx" but
   initialize "xx_YY", initializing "xx". Previously we would do nothing.
 * Skip extracting messages that pass the 'skip' argument to Intl calls.
 * Move analyzer dependency up to 0.32.0

## 0.16.1
 * Add @@last_modified to extracted ARB files.
 * Handle @@locale in translated ARB files properly, and adds a --locale
   parameter to specify the locale.
 * Adds a --output-file parameter to extract_to_arb
 * Indent the output file for ARB for better readability.
 * A couple of tweaks to satisfy Flutter's default linter rules when run on the
   generated code.

## 0.16.0
  * BREAKING CHANGE: Require that the examples to message/plural/gender/select
    calls be const. DDC does not optimize non-const maps well, so it's a
    significant performance issue if these are non-const.
  * Added a utility to convert examples in calls to be const. See
    bin/make_examples_const.dart
  * Add a codegen_mode flag, which can be either release or debug. In release
    mode a missing translation throws an exception, in debug mode it returns the
    original text, which was the previous behavior.
  * Add support for generating translated messages as JSON rather than
    methods. This can significantly improve dart2js compile times for
    applications with many translations. The JSON is a literal string in the
    deferred library, so usage doesn't change at all.

## 0.15.0
  * Change non-transformer message rewriting to preserve the original message as
    much as possible. Adds --useStringSubstitution command-line arg.
  * Change non-transformer message rewriting to allow multiple input files to be
    specified on the command line. Adds --replace flag to ignore --output option
    and just replace files.
  * Make non-transformer message rewriting also run dartfmt on the output.
  * Make message extraction more robust: error message instead of stack trace
    when an Intl call is made outside a method, when a prefixed expression is
    used in an interpolation, and when a non-required example Map is not a
    literal.
  * Make message extraction more robust: if parsing triggers an exception then
    report it as an error instead of exiting.
  * Move barback to being a normal rather than a dev dependency.
  * Add a check for invalid select keywords.
  * Added a post-message construction validate, moved
    IntlMessageExtractionException into intl_message.dart
  * Make use of analyzer's new AstFactory class (requires analyzer version
    0.29.1).
  * Fix error in transformer, pass the path instead of the asset id.
  * Prefer an explicit =0/=1/=2 to a ZERO/ONE/TWO if both are present. We don't
    distinguish the two as Intl.message arguments, we just have the "one"
    parameter, which we confusingly write out as =1. Tools interpret these
    differently, and in particular, a ONE clause is used for the zero case if
    there's no explicit zero. Translation tools may implement this by filling in
    both ZERO and ONE values with the OTHER clause when there's no ZERO
    provided, resulting in a translation with both =1 and ONE clauses which are
    different. We should prefer the explicit =1 in that case. In future we may
    distinguish the different forms, but that would probably break existing
    translations.
  * Switch to using package:test
  * Give a more specific type in the generated code to keep lints happy.

## 0.14.0
  * Split message extraction and code generation out into a separate
    package. Versioned to match the corresponding Intl version.
