// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:intl_translation/src/intl_message.dart';

/// This is a placeholder for transforming a parameter substitution from
/// the translation file format into a Dart interpolation. In our case we
/// store it to the file in Dart interpolation syntax, so the transformation
/// is trivial.
String leaveTheInterpolationsInDartForm(MainMessage msg, dynamic chunk) {
  if (chunk is String) {
    return chunk;
  } else if (chunk is int) {
    return '\$${msg.arguments[chunk]}';
  } else if (chunk is Message) {
    return chunk.toCode();
  } else {
    throw FormatException('Illegal interpolation: $chunk');
  }
}

/// Convert the [MainMessage] to a trivial JSON format.
Map<String, dynamic> toARB(
  MainMessage message, {
  bool supressMetadata = false,
  bool includeSourceText = false,
}) {
  Map<String, dynamic> out = {};
  if (message.messagePieces.isEmpty) return out;

  // Return a version of the message string with with ICU parameters
  // "{variable}" rather than Dart interpolations "$variable".
  out[message.name] = message
      .expanded((msg, chunk) => turnInterpolationIntoICUForm(msg, chunk));

  if (!supressMetadata) {
    Map<String, dynamic> arbMetadataForMessage = arbMetadata(message);
    out['@${message.name}'] = arbMetadataForMessage;
    if (includeSourceText) {
      arbMetadataForMessage['source_text'] = out[message.name];
    }
  }
  return out;
}

Map<String, dynamic> arbMetadata(MainMessage message) {
  Map<String, dynamic> out = {};
  String? desc = message.description;
  if (desc != null) {
    out['description'] = desc;
  }
  out['type'] = 'text';
  Map<String, dynamic> placeholders = {};
  for (String arg in message.arguments) {
    addArgumentFor(message, arg, placeholders);
  }
  out['placeholders'] = placeholders;
  return out;
}

void addArgumentFor(
  MainMessage message,
  String arg,
  Map<String, dynamic> result,
) {
  Map<String, dynamic> extraInfo = {};
  if (message.examples[arg] != null) {
    extraInfo['example'] = message.examples[arg];
  }
  result[arg] = extraInfo;
}

String turnInterpolationIntoICUForm(
  Message message,
  dynamic chunk, {
  bool shouldEscapeICU = false,
}) {
  if (chunk is String) {
    return shouldEscapeICU ? escape(chunk) : chunk;
  } else if (chunk is int && chunk >= 0 && chunk < message.arguments.length) {
    return '{${message.arguments[chunk]}}';
  } else if (chunk is SubMessage) {
    return chunk.expanded((message, chunk) => turnInterpolationIntoICUForm(
          message,
          chunk,
          shouldEscapeICU: true,
        ));
  } else if (chunk is Message) {
    return chunk.expanded((message, chunk) => turnInterpolationIntoICUForm(
          message,
          chunk,
          shouldEscapeICU: shouldEscapeICU,
        ));
  }
  throw FormatException('Illegal interpolation: $chunk');
}

String escape(String s) {
  return s.replaceAll("'", "''").replaceAll('{', "'{'").replaceAll('}', "'}'");
}
