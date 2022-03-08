// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:intl_translation/src/intl_message.dart';

/// This is a placeholder for transforming a parameter substitution from
/// the translation file format into a Dart interpolation. In our case we
/// store it to the file in Dart interpolation syntax, so the transformation
/// is trivial.
String leaveTheInterpolationsInDartForm(MainMessage msg, chunk) {
  if (chunk is String) return chunk;
  if (chunk is int) return "\$${msg.arguments[chunk]}";
  return chunk.toCode();
}

/// Convert the [MainMessage] to a trivial JSON format.
Map toARB(
  MainMessage message, {
  bool supressMetadata = false,
  bool includeSourceText = false,
}) {
  if (message.messagePieces.isEmpty) return null;
  var out = {};
  out[message.name] = icuForm(message);

  if (!supressMetadata) {
    out["@${message.name}"] = arbMetadata(message);

    if (includeSourceText) {
      out["@${message.name}"]["source_text"] = out[message.name];
    }
  }

  return out;
}

Map arbMetadata(MainMessage message) {
  var out = {};
  var desc = message.description;
  if (desc != null) {
    out["description"] = desc;
  }
  out["type"] = "text";
  var placeholders = {};
  for (var arg in message.arguments) {
    addArgumentFor(message, arg, placeholders);
  }
  out["placeholders"] = placeholders;
  return out;
}

void addArgumentFor(MainMessage message, String arg, Map result) {
  var extraInfo = {};
  if (message.examples != null && message.examples[arg] != null) {
    extraInfo["example"] = message.examples[arg];
  }
  result[arg] = extraInfo;
}

/// Return a version of the message string with with ICU parameters "{variable}"
/// rather than Dart interpolations "$variable".
String icuForm(MainMessage message) =>
    message.expanded(turnInterpolationIntoICUForm);

String turnInterpolationIntoICUForm(Message message, chunk,
    {bool shouldEscapeICU: false}) {
  if (chunk is String) {
    return shouldEscapeICU ? escape(chunk) : chunk;
  }
  if (chunk is int && chunk >= 0 && chunk < message.arguments.length) {
    return "{${message.arguments[chunk]}}";
  }
  if (chunk is SubMessage) {
    return chunk.expanded((message, chunk) =>
        turnInterpolationIntoICUForm(message, chunk, shouldEscapeICU: true));
  }
  if (chunk is Message) {
    return chunk.expanded((message, chunk) => turnInterpolationIntoICUForm(
        message, chunk,
        shouldEscapeICU: shouldEscapeICU));
  }
  throw new FormatException("Illegal interpolation: $chunk");
}

String escape(String s) {
  return s.replaceAll("'", "''").replaceAll("{", "'{'").replaceAll("}", "'}'");
}
