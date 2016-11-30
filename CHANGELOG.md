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

## 0.14.0
  * Split message extraction and code generation out into a separate
    package. Versioned to match the corresponding Intl version.
