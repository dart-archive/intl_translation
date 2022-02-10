// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A test library that should fail because there is a Intl.select with out of
/// order arg list.
library select_arg_order;

import "package:intl/intl.dart";

selectArgs(arg, choice) =>
    Intl.select(choice, {'a': 'nothing $arg', 'b': 'one $arg'},
        name: 'selectArgs', desc: 'Select and arg', args: [arg, choice]);
