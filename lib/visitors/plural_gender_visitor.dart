import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:intl_translation/extract_messages.dart';
import 'package:intl_translation/src/messages/complex_message.dart';
import 'package:intl_translation/src/messages/message.dart';
import 'package:intl_translation/src/messages/message_extraction_exception.dart';
import 'package:intl_translation/src/messages/submessages/gender.dart';
import 'package:intl_translation/src/messages/submessages/plural.dart';
import 'package:intl_translation/src/messages/submessages/select.dart';
import 'package:intl_translation/src/messages/submessages/submessage.dart';
import 'package:intl_translation/visitors/interpolation_visitor.dart';

/// A visitor to extract information from Intl.plural/gender sends. Note that
/// this is a SimpleAstVisitor, so it doesn't automatically recurse. So this
/// needs to be called where we expect a plural or gender immediately below.
class PluralAndGenderVisitor extends SimpleAstVisitor<void> {
  /// The message extraction in which we are running.
  final MessageExtraction extraction;

  /// A plural or gender always exists in the context of a parent message,
  /// which could in turn also be a plural or gender.
  final ComplexMessage parent;

  /// The pieces of the message. We are given an initial version of this
  /// from our parent and we add to it as we find additional information.
  List pieces;

  /// This will be set to true if we find a plural or gender.
  bool foundPluralOrGender = false;

  PluralAndGenderVisitor(this.pieces, this.parent, this.extraction) : super();

  @override
  void visitInterpolationExpression(InterpolationExpression node) {
    // TODO(alanknight): Provide better errors for malformed expressions.
    if (!looksLikePluralOrGender(node.expression)) return;
    MethodInvocation nodeMethod = node.expression as MethodInvocation;
    String? reason = checkValidity(nodeMethod);
    if (reason != null) {
      throw reason; //TODO: What does throwing a string do? Is it an error or an exception?
    }
    Message? message = messageFromMethodInvocation(nodeMethod);
    foundPluralOrGender = true;
    pieces.add(message);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    pieces.add(messageFromMethodInvocation(node));
  }

  /// Return true if [node] matches the pattern for plural or gender message.
  bool looksLikePluralOrGender(Expression expression) {
    if (expression is! MethodInvocation) return false;
    final node = expression;
    if (!['plural', 'gender', 'select'].contains(node.methodName.name)) {
      return false;
    }
    if (node.target is! SimpleIdentifier) return false;
    SimpleIdentifier target = node.target as SimpleIdentifier;
    return target.token.toString() == 'Intl';
  }

  /// Returns a String describing why the node is invalid, or null if no
  /// reason is found, so it's presumed valid.
  String? checkValidity(MethodInvocation node) {
    // TODO(alanknight): Add reasonable validity checks.
    return null;
  }

  /// Create a MainMessage from [node] using the name and
  /// parameters of the last function/method declaration we encountered
  /// and the parameters to the Intl.message call.
  Message? messageFromMethodInvocation(MethodInvocation node) {
    SubMessage? message;
    Map<String, Expression> arguments;
    switch (node.methodName.name) {
      case 'gender':
        message = Gender();
        arguments = SubMessage.argumentsOfInterestFor(node);
        break;
      case 'plural':
        message = Plural();
        arguments = SubMessage.argumentsOfInterestFor(node);
        break;
      case 'select':
        message = Select();
        arguments = Select.argumentsOfInterestFor(node);
        break;
      default:
        throw MessageExtractionException(
            'Invalid plural/gender/select message ${node.methodName.name} '
            'in $node');
    }
    message.parent = parent;

    arguments.forEach((key, Expression value) {
      // `value` is often - or always? - an Expression.//TODO: If its not, what else can have an accept method?
      try {
        InterpolationVisitor interpolation = InterpolationVisitor(
          message!,
          extraction,
        );
        value.accept(interpolation);
        // Might be null due to previous errors.
        // Continue collecting errors, but don't build message.
        //TODO: How can this be null??
        if (message != null) {
          message![key] = interpolation.pieces;
        }
      } on MessageExtractionException catch (e) {
        message = null;
        StringBuffer err = StringBuffer()
          ..writeAll(['Error ', e, '\nProcessing <', node, '>'])
          ..write(extraction.reportErrorLocation(node));
        String errString = err.toString();
        extraction.onMessage(errString);
        extraction.warnings.add(errString);
      }
    });
    Expression mainArg = node.argumentList.arguments
        .firstWhere((each) => each is! NamedExpression);
    if (mainArg is SimpleStringLiteral) {
      message?.mainArgument = mainArg.toString();
    } else if (mainArg is SimpleIdentifier) {
      message?.mainArgument = mainArg.name;
    } else {
      String errString = (StringBuffer()
            ..write('Error (Invalid argument to plural/gender/select, '
                'must be simple variable reference) '
                '\nProcessing <$node>')
            ..write(extraction.reportErrorLocation(node)))
          .toString();
      extraction.onMessage(errString);
      extraction.warnings.add(errString);
    }

    return message;
  }
}
