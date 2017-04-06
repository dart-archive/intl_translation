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

## 0.14.0
  * Split message extraction and code generation out into a separate
    package. Versioned to match the corresponding Intl version.
