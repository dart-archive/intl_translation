/// This provides a way for a test to print to an internal list so the
/// results can be verified rather than writing to and reading a file.

// @dart=2.10

library print_to_list.dart;

List<String> lines = [];

void printOut(String s) {
  lines.add(s);
}
