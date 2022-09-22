// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/ast/constant_evaluator.dart';
import 'package:intl_translation/extract_messages.dart';
import 'package:intl_translation/src/messages/main_message.dart';
import 'package:intl_translation/src/messages/message.dart';
import 'package:intl_translation/src/messages/message_extraction_exception.dart';
import 'package:intl_translation/src/messages/submessages/gender.dart';
import 'package:intl_translation/src/messages/submessages/plural.dart';
import 'package:intl_translation/visitors/interpolation_visitor.dart';
import 'package:intl_translation/visitors/plural_gender_visitor.dart';

/// This visits the program source nodes looking for Intl.message uses
/// that conform to its pattern and then creating the corresponding
/// IntlMessage objects. We have to find both the enclosing function, and
/// the Intl.message invocation.
class MessageFindingVisitor extends GeneralizingAstVisitor {
  MessageFindingVisitor(this.extraction, {this.generateNameAndArgs = false});

  /// The message extraction in which we are running.
  final MessageExtraction extraction;

  /// Accumulates the messages we have found, keyed by name.
  final Map<String, MainMessage> messages = <String, MainMessage>{};

  /// Should we generate the name and arguments from the function definition,
  /// meaning we're running in the transformer.
  final bool generateNameAndArgs;

  // We keep track of the data from the last MethodDeclaration,
  // FunctionDeclaration or FunctionExpression that we saw on the way down,
  // as that will be the nearest parent of the Intl.message invocation.
  /// Parameters of the currently visited method.
  List<FormalParameter>? parameters;

  /// Name of the currently visited method.
  String? name;

  /// Dartdoc of the currently visited method.
  Comment? documentation;

  final List<FormalParameter> _emptyParameterList = const [];

  /// Return true if [node] matches the pattern we expect for Intl.message()
  bool looksLikeIntlMessage(MethodInvocation node) {
    const validNames = ['message', 'plural', 'gender', 'select'];
    if (!validNames.contains(node.methodName.name)) return false;
    final target = node.target;
    if (target is SimpleIdentifier) {
      return target.token.toString() == 'Intl';
    } else if (target is PrefixedIdentifier) {
      return target.identifier.token.toString() == 'Intl';
    }
    return false;
  }

  /// Returns a String describing why the node is invalid, or null if no
  /// reason is found, so it's presumed valid.
  String? _checkValidity(MethodInvocation node) {
    if (parameters == null) {
      return 'Calls to Intl must be inside a method, field declaration or '
          'top level declaration.';
    }
    // The containing function cannot have named parameters.
    if (parameters!.any((each) => each.isNamed)) {
      return 'Named parameters on message functions are not supported.';
    }
    NodeList<Expression> arguments = node.argumentList.arguments;
    if (node.methodName.name == 'message') {
      return MainMessage.checkValidity(
        node,
        arguments,
        name,
        parameters!,
        nameAndArgsGenerated: generateNameAndArgs,
        examplesRequired: extraction.examplesRequired,
      );
    } else if (['plural', 'gender', 'select'].contains(node.methodName.name)) {
      return Message.checkValidity(
        node,
        arguments,
        name,
        parameters!,
        nameAndArgsGenerated: generateNameAndArgs,
        examplesRequired: extraction.examplesRequired,
      );
    }
    throw Exception('wrong methodname'); //TODO: nicer exception
  }

  /// Record the parameters of the function or method declaration we last
  /// encountered before seeing the Intl.message call.
  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    setFields(
      name: node.name.name,
      parameters: node.parameters?.parameters,
      documentation: node.documentationComment,
    );
    super.visitMethodDeclaration(node);
    resetFields();
  }

  /// Record the parameters of the function or method declaration we last
  /// encountered before seeing the Intl.message call.
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    setFields(
      name: node.name.name,
      parameters: node.functionExpression.parameters?.parameters,
      documentation: node.documentationComment,
    );
    super.visitFunctionDeclaration(node);
    resetFields();
  }

  /// Record the name of field declaration we last
  /// encountered before seeing the Intl.message call.
  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    // We don't support names in list declarations,
    // e.g. String first, second = Intl.message(...);
    setFields(
      name: node.fields.variables.length == 1
          ? node.fields.variables.first.name.name
          : null,
      documentation: node.documentationComment,
    );
    super.visitFieldDeclaration(node);
    resetFields();
  }

  /// Record the name of the top level variable declaration we last
  /// encountered before seeing the Intl.message call.
  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    // We don't support names in list declarations,
    // e.g. String first, second = Intl.message(...);
    setFields(
      name: node.variables.variables.length == 1
          ? node.variables.variables.first.name.name
          : null,
      documentation: node.documentationComment,
    );
    super.visitTopLevelVariableDeclaration(node);
    resetFields();
  }

  void setFields({
    String? name,
    List<FormalParameter>? parameters,
    Comment? documentation,
  }) {
    this.name = name;
    this.parameters = parameters ?? _emptyParameterList;
    this.documentation = documentation;
  }

  void resetFields() {
    name = null;
    parameters = null;
    documentation = null;
  }

  /// Examine method invocations to see if they look like calls to Intl.message.
  /// If we've found one, stop recursing. This is important because we can have
  /// Intl.message(...Intl.plural...) and we don't want to treat the inner
  /// plural as if it was an outermost message.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!addIntlMessage(node)) {
      super.visitMethodInvocation(node);
    }
  }

  /// Check that the node looks like an Intl.message invocation, and create
  /// the [IntlMessage] object from it and store it in [messages]. Return true
  /// if we successfully extracted a message and should stop looking. Return
  /// false if we didn't, so should continue recursing.
  bool addIntlMessage(MethodInvocation node) {
    if (!looksLikeIntlMessage(node)) return false;
    String? reason = _checkValidity(node) ?? _extractMessage(node);
    if (reason != null) {
      if (!extraction.suppressWarnings) {
        String errString = (StringBuffer()
              ..write('Skipping invalid Intl.message invocation\n    <$node>\n')
              ..writeAll([
                '    reason: $reason\n',
                extraction.reportErrorLocation(node)
              ]))
            .toString();
        extraction.warnings.add(errString);
        extraction.onMessage(errString);
      }
    }

    // We found a message, valid or not. Stop recursing.
    return true;
  }

  /// Try to extract a message. On failure, return a String error message.
  String? _extractMessage(MethodInvocation node) {
    MainMessage? message;
    try {
      if (node.methodName.name == 'message') {
        message = messageFromIntlMessageCall(node);
      } else {
        message = messageFromDirectPluralOrGenderCall(node);
      }
    } catch (e, s) {
      return 'Unexpected exception: $e, $s';
    }
    return message == null ? null : _validateMessage(message);
  }

  /// Perform any post-construction validations on the message and
  /// ensure that it's not a duplicate.
  // TODO(alanknight): This is still ugly and may lead to duplicate reporting
  // of the same error. Refactor to consistently throw
  // IntlMessageExtractionException instead of returning strings and centralize
  // the reporting.
  String? _validateMessage(MainMessage message) {
    try {
      message.validate();
      if (extraction.descriptionRequired) {
        message.validateDescription();
      }
    } on MessageExtractionException catch (e) {
      return e.message;
    }
    var existing = messages[message.name];
    if (existing != null) {
      if (!message.skip! && extraction.mergeMessages != null) {
        messages[message.name] = extraction.mergeMessages!(existing, message);
      }
      // TODO(alanknight): We may want to require the descriptions to match.
      String existingCode = existing.toOriginalCode(
        includeDesc: false,
        includeExamples: false,
      );
      String messageCode = message.toOriginalCode(
        includeDesc: false,
        includeExamples: false,
      );
      if (existingCode != messageCode) {
        return 'WARNING: Duplicate message name:\n'
            "'${message.name}' occurs more than once in ${extraction.origin}";
      }
    } else if (!message.skip!) {
      messages[message.name] = message;
    }
    return null;
  }

  /// Create a MainMessage from [node] using the name and
  /// parameters of the last function/method declaration we encountered,
  /// and the values we get by calling [extract]. We set those values
  /// by calling [setAttribute]. This is the common parts between
  /// [messageFromIntlMessageCall] and [messageFromDirectPluralOrGenderCall].
  MainMessage? _messageFromNode(
    MethodInvocation node,
    MainMessage? Function(MainMessage message, List<AstNode> arguments) extract,
    void Function(MainMessage message, String fieldName, Object? fieldValue)
        setAttribute,
  ) {
    MainMessage message = MainMessage(
      sourcePosition: node.offset,
      endPosition: node.end,
      arguments: parameters!.map((x) => x.identifier!.name).toList(),
    );
    documentation?.tokens
        .map((token) => token.toString())
        .forEach((s) => message.documentation.add(s));
    NodeList<Expression> arguments = node.argumentList.arguments;
    if (extract(message, arguments) == null) {
      return null;
    }
    for (NamedExpression namedExpr in arguments.whereType<NamedExpression>()) {
      String name = namedExpr.name.label.name;
      Expression exp = namedExpr.expression;
      Object? basicValue = exp.accept(ConstantEvaluator());
      Object? value = basicValue == ConstantEvaluator.NOT_A_CONSTANT
          ? exp.toString()
          : basicValue;
      setAttribute(message, name, value);
    }
    // We only rewrite messages with parameters, otherwise we use the literal
    // string as the name and no arguments are necessary.
    if (message.hasNoName) {
      if (generateNameAndArgs && message.arguments.isNotEmpty) {
        // Always try for class_method if this is a class method and
        // generating names/args.
        message.name = Message.classPlusMethodName(node, name) ?? name;
      } else if (arguments.first is SimpleStringLiteral ||
          arguments.first is AdjacentStrings) {
        // If there's no name, and the message text is a simple string, compute
        // a name based on that plus meaning, if present.
        String? simpleName = (arguments.first as StringLiteral).stringValue;
        message.name = computeMessageName(
          message.name,
          simpleName,
          message.meaning,
        );
      }
    }
    return message;
  }

  /// Find the message pieces from a Dart interpolated string.
  List _extractFromIntlCallWithInterpolation(
    MainMessage message,
    AstNode node,
  ) {
    InterpolationVisitor interpolation = InterpolationVisitor(
      message,
      extraction,
    );
    node.accept(interpolation);
    if (interpolation.pieces.any((x) => x is Plural || x is Gender) &&
        !extraction.allowEmbeddedPluralsAndGenders) {
      if (interpolation.pieces.whereType<String>().any((x) => x.isNotEmpty)) {
        throw MessageExtractionException(
            'Plural and gender expressions must be at the top level, '
            'they cannot be embedded in larger string literals.\n');
      }
    }
    return interpolation.pieces;
  }

  /// Create a MainMessage from [node] using the name and
  /// parameters of the last function/method declaration we encountered
  /// and the parameters to the Intl.message call.
  MainMessage? messageFromIntlMessageCall(MethodInvocation node) {
    MainMessage? extractFromIntlCall(
        MainMessage message, List<AstNode> arguments) {
      try {
        // The pieces of the message, either literal strings, or integers
        // representing the index of the argument to be substituted.
        List extracted = _extractFromIntlCallWithInterpolation(
          message,
          arguments.first,
        );
        message.addPieces(extracted.cast<Object>());
      } on MessageExtractionException catch (e) {
        String errString = (StringBuffer()
              ..writeAll(['Error ', e, '\nProcessing <', node, '>\n'])
              ..write(extraction.reportErrorLocation(node)))
            .toString();
        extraction.onMessage(errString);
        extraction.warnings.add(errString);
        return null;
      }
      return message;
    }

    void setValue(MainMessage message, String fieldName, Object? fieldValue) {
      message[fieldName] = fieldValue;
    }

    return _messageFromNode(node, extractFromIntlCall, setValue);
  }

  /// Create a MainMessage from [node] using the name and
  /// parameters of the last function/method declaration we encountered
  /// and the parameters to the Intl.plural or Intl.gender call.
  MainMessage? messageFromDirectPluralOrGenderCall(MethodInvocation node) {
    MainMessage extractFromPluralOrGender(MainMessage message, _) {
      PluralAndGenderVisitor visitor = PluralAndGenderVisitor(
        message.messagePieces,
        message,
        extraction,
      );
      node.accept(visitor);
      return message;
    }

    void setAttribute(MainMessage msg, String fieldName, fieldValue) {
      if (msg.attributeNames.contains(fieldName)) {
        msg[fieldName] = fieldValue;
      }
    }

    return _messageFromNode(node, extractFromPluralOrGender, setAttribute);
  }
}