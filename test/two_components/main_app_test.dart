// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// An application using the component

import "package:intl/intl.dart";
import "app_messages_all.dart";
import "package:test/test.dart";
import "component.dart" as component;

appMessage() => Intl.message("Hello from application", desc: 'hi');

main() async {
  Intl.defaultLocale = "fr";
  await initializeMessages("fr");
  await component.initComponent();
  test("Component has its own messages", () {
    expect(appMessage(), "Bonjour de l'application");
    expect(component.componentApiFunction(), "Bonjour du composant");
    expect(component.directApiCall(), "Locale explicite");
  });
}
