## 0.15.0
  * Change non-transformer message rewriting to preserve the original message as
    much as possible. Adds --useStringSubstitution command-line arg.
  * Change non-transformer message rewriting to allow multiple input files to be
    specified on the command line. Adds --replace flag to ignore --output option
    and just replace files.
  * Make non-transformer message rewriting also run dartfmt on the output.

## 0.14.0
  * Split message extraction and code generation out into a separate
    package. Versioned to match the corresponding Intl version.
