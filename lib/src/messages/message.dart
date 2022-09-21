/// This provides classes to represent the internal structure of the
/// arguments to `Intl.message`. It is used when parsing sources to extract
/// messages or to generate code for message substitution. Normal programs
/// using Intl would not import this library.
///
/// While it's written
/// in a somewhat abstract way, it has some assumptions about ICU-style
/// message syntax for parameter substitutions, choices, selects, etc.
///
/// For example, if we have the message
///      plurals(num) => Intl.message("""${Intl.plural(num,
///          zero : 'Is zero plural?',
///          one : 'This is singular.',
///          other : 'This is plural ($num).')
///         }""",
///         name: "plurals", args: [num], desc: "Basic plurals");
/// That is represented as a MainMessage which has only one message component, a
/// Plural, but also has a name, list of arguments, and a description.
/// The Plural has three different clauses. The `zero` clause is
/// a LiteralString containing 'Is zero plural?'. The `other` clause is a
/// CompositeMessage containing three pieces, a LiteralString for
/// 'This is plural (', a VariableSubstitution for `num`. amd a LiteralString
/// for '.)'.
///
/// This representation isn't used at runtime. Rather, we read some format
/// from a translation file, parse it into these objects, and they are then
/// used to generate the code representation above.
///
// ignore_for_file: deprecated_member_use, #168
library intl_message;

import 'dart:convert';

import 'package:analyzer/dart/ast/ast.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/ast/constant_evaluator.dart';
import 'package:intl_translation/src/messages/literal_string_message.dart';
import 'package:intl_translation/src/messages/variable_substitution_message.dart';

import 'complex_message.dart';
import 'composite_message.dart';

const jsonEncoder = JsonCodec();

/// A default function for the [Message.expanded] method.
String nullTransform(dynamic msg, dynamic chunk) => chunk as String;

/// An abstract superclass for Intl.message/plural/gender calls in the
/// program's source text. We
/// assemble these into objects that can be used to write out some translation
/// format and can also print themselves into code.
abstract class Message {
  /// All [Message]s except a [MainMessage] are contained inside some parent,
  /// terminating at an Intl.message call which supplies the arguments we
  /// use for variable substitutions.
  Message? parent;

  Message(this.parent);

  /// We find the arguments from the top-level [MainMessage] and use those to
  /// do variable substitutions. [MainMessage] overrides this to return
  /// the actual arguments.
  List<String> get arguments => parent == null ? const [] : parent!.arguments;

  /// We find the examples from the top-level [MainMessage] and use those
  /// when writing out variables. [MainMessage] overrides this to return
  /// the actual examples.
  Map<String, dynamic> get examples =>
      parent == null ? const {} : parent!.examples;

  /// The name of the top-level [MainMessage].
  String get name => parent == null ? '<unnamed>' : parent!.name;

  static final _evaluator = ConstantEvaluator();

  static String? _evaluateAsString(expression) {
    var result = expression.accept(_evaluator);
    if (result == ConstantEvaluator.NOT_A_CONSTANT || result is! String) {
      return null;
    } else {
      return result;
    }
  }

  static Map? _evaluateAsMap(Expression expression) {
    var result = expression.accept(_evaluator);
    if (result == ConstantEvaluator.NOT_A_CONSTANT || result is! Map) {
      return null;
    } else {
      return result;
    }
  }

  /// Verify that the args argument matches the method parameters and
  /// isn't, e.g. passing string names instead of the argument values.
  static bool checkArgs(NamedExpression? args, List<String> parameterNames) {
    if (args == null) return true;
    // Detect cases where args passes invalid names, either literal strings
    // instead of identifiers, or in the wrong order, missing values, etc.
    ListLiteral identifiers = args.childEntities.last as ListLiteral;
    if (!identifiers.elements.every((each) => each is SimpleIdentifier)) {
      return false;
    }
    var names = identifiers.elements
        .map((each) => (each as SimpleIdentifier).name)
        .toList();
    Map<String, String> both;
    try {
      both = Map.fromIterables(names, parameterNames);
    } catch (e) {
      // Most likely because sizes don't match.
      return false;
    }
    var everythingMatches = true;
    both.forEach((name, parameterName) {
      if (name != parameterName) everythingMatches = false;
    });
    return everythingMatches;
  }

  /// Verify that this looks like a correct
  /// Intl.message/plural/gender/... invocation.
  ///
  /// We expect an invocation like
  ///
  ///       outerName(x) => Intl.message("foo \$x", ...)
  ///
  /// The [node] parameter is the Intl.message invocation node in the AST,
  /// [arguments] is the list of arguments to that node (also reachable as
  /// node.argumentList.arguments), [outerName] is the name of the containing
  /// function, e.g. "outerName" in this case and [outerArgs] is the list of
  /// arguments to that function. Of the optional parameters
  /// [nameAndArgsGenerated] indicates if we are generating names and arguments
  /// while rewriting the code in the transformer or a development-time rewrite,
  /// so we should not expect them to be present. The [examplesRequired]
  /// parameter indicates if we will fail if parameter examples are not provided
  /// for messages with parameters.
  static String? checkValidity(
    MethodInvocation node,
    List arguments,
    String? outerName,
    List<FormalParameter> outerArgs, {
    bool nameAndArgsGenerated = false,
    bool examplesRequired = false,
  }) {
    // If we have parameters, we must specify args and name.
    Iterable<NamedExpression> argsNamedExps = arguments
        .whereType<NamedExpression>()
        .where((each) => each.name.label.name == 'args');
    NamedExpression? args =
        argsNamedExps.isNotEmpty ? argsNamedExps.first : null;
    var parameterNames = outerArgs.map((x) => x.identifier!.name).toList();
    var hasArgs = args != null;
    var hasParameters = outerArgs.isNotEmpty;
    if (!nameAndArgsGenerated && !hasArgs && hasParameters) {
      return "The 'args' argument for Intl.message must be specified for "
          'messages with parameters. Consider using rewrite_intl_messages.dart';
    }
    if (!checkArgs(args, parameterNames)) {
      return "The 'args' argument must match the message arguments,"
          ' e.g. args: $parameterNames';
    }
    Iterable<Expression> nameNamedExps = arguments
        .whereType<NamedExpression>()
        .where((arg) => arg.name.label.name == 'name')
        .map((e) => e.expression);
    String? messageName;
    String? givenName;

    //TODO(alanknight): If we generalize this to messages with parameters
    // this check will need to change.
    if (nameNamedExps.isEmpty) {
      if (!hasParameters) {
        // No name supplied, no parameters. Use the message as the name.
        messageName = _evaluateAsString(arguments[0]);
        outerName = messageName;
      } else {
        // We have no name and parameters, but the transformer generates the
        // name.
        if (nameAndArgsGenerated) {
          givenName = outerName;
          messageName = givenName;
        } else {
          return "The 'name' argument for Intl.message must be supplied for "
              'messages with parameters. Consider using '
              'rewrite_intl_messages.dart';
        }
      }
    } else {
      // Name argument is supplied, use it.
      givenName = _evaluateAsString(nameNamedExps.first);
      messageName = givenName;
    }

    if (messageName == null) {
      return "The 'name' argument for Intl.message must be a string literal";
    }

    bool hasOuterName = outerName != null;
    bool simpleMatch = outerName == givenName || givenName == null;

    String? classPlusMethod = Message.classPlusMethodName(node, outerName);
    bool classMatch = classPlusMethod != null && (givenName == classPlusMethod);
    if (!(hasOuterName && (simpleMatch || classMatch))) {
      return "The 'name' argument for Intl.message must match either "
          'the name of the containing function or <ClassName>_<methodName> ('
          "was '$givenName' but must be '$outerName'  or '$classPlusMethod')";
    }

    List<Expression> values = arguments
        .whereType<NamedExpression>()
        .where((each) => ['desc', 'name'].contains(each.name.label.name))
        .map((each) => each.expression)
        .toList();
    for (Expression arg in values) {
      if (_evaluateAsString(arg) == null) {
        return 'Intl.message arguments must be string literals: $arg';
      }
    }

    if (hasParameters) {
      Iterable<Expression> examples = arguments
          .whereType<NamedExpression>()
          .where((each) => each.name.label.name == 'examples')
          .map((each) => each.expression);
      if (examples.isEmpty && examplesRequired) {
        return 'Examples must be provided for messages with parameters';
      }
      if (examples.isNotEmpty) {
        Expression example = examples.first;
        Map? map = _evaluateAsMap(example);
        if (map == null) {
          return 'Examples must be a const Map literal.';
        }
        // if (example.constKeyword == null) { //TODO:What does this mean? Why would one check for it?
        //   return 'Examples must be const.';
        // }
      }
    }

    return null;
  }

  /// Verify that a constructed message is valid.
  ///
  /// This is called after the message has already been built, as opposed
  /// to checkValidity which is called before creation. It can be used to
  /// validate conditions that can just be checked against the result,
  /// and/or are simpler to check there than on the AST nodes. For example,
  /// is a required clause like "other" included, or are there examples
  /// for all of the parameters. It should throw an
  /// IntlMessageExtractionException for errors.
  void validate() {}

  /// Return the name of the enclosing class (if any) plus method name, or null
  /// if there's no enclosing class.
  ///
  /// For a method foo in class Bar we allow either "foo" or "Bar_Foo" as the
  /// name.
  static String? classPlusMethodName(MethodInvocation node, String? outerName) {
    ClassOrMixinDeclaration? classNode(AstNode? n) {
      if (n == null) return null;
      if (n is ClassOrMixinDeclaration) return n;
      return classNode(n.parent);
    }

    var classDeclaration = classNode(node);
    return classDeclaration == null
        ? null
        : '${classDeclaration.name.token}_$outerName';
  }

  /// Turn a value, typically read from a translation file or created out of an
  /// AST for a source program, into the appropriate
  /// subclass. We expect to get literal Strings, variable substitutions
  /// represented by integers, things that are already MessageChunks and
  /// lists of the same.
  static Message from(Object? value, Message parent) {
    if (value is String) return LiteralString(value, parent);
    if (value is int) return VariableSubstitution(value, parent);
    if (value is List) {
      if (value.length == 1) return Message.from(value[0], parent);
      var result = CompositeMessage([], parent as ComplexMessage?);
      var items = value.map((x) => from(x, result)).toList();
      result.pieces.addAll(items);
      return result;
    }
    // We assume this is already a Message.
    Message mustBeAMessage = value as Message;
    mustBeAMessage.parent = parent;
    return mustBeAMessage;
  }

  /// Return a string representation of this message for use in generated Dart
  /// code.
  String toCode();

  /// Return a JSON-storable representation of this message which can be
  /// interpolated at runtime.
  Object? toJson();

  /// Escape the string for use in generated Dart code.
  String escapeAndValidateString(String value) {
    const Map<String, String> escapes = {
      r'\': r'\\',
      '"': r'\"',
      '\b': r'\b',
      '\f': r'\f',
      '\n': r'\n',
      '\r': r'\r',
      '\t': r'\t',
      '\v': r'\v',
      "'": r"\'",
      r'$': r'\$'
    };

    var escaped = value.splitMapJoin(
      '',
      onNonMatch: (String string) => escapes[string] ?? string,
    );
    return escaped;
  }

  /// Expand this string out into a printed form. The function [f] will be
  /// applied to any sub-messages, allowing this to be used to generate a form
  /// suitable for a wide variety of translation file formats.
  String expanded([String Function(dynamic, dynamic) transform]);
}
