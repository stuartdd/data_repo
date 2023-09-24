import 'package:flutter_test/flutter_test.dart';
import 'package:data_repo/logging.dart';

void main() {
  //
  test('Test logger without extra line for markdown', () async {
    final log = Logger(3, false);
    expect(log.length, 0);
    expect(log.toString(), "");
    log.log("ONE");
    expect(log.length, 1);
    expect(log.toString(), "ONE");
    log.log("TWO");
    expect(log.length, 2);
    expect(log.toString(), "ONE\nTWO");
    log.log("THREE");
    expect(log.length, 3);
    expect(log.toString(), "ONE\nTWO\nTHREE");
    log.log("FOUR");
    expect(log.length, 3);
    expect(log.toString(), "TWO\nTHREE\nFOUR");
    log.log("FIVE");
    expect(log.length, 3);
    expect(log.toString(), "THREE\nFOUR\nFIVE");
  });

  test('Test logger WITH extra line for markdown', () async {
    final log = Logger(3, true);
    expect(log.length, 0);
    expect(log.toString(), "");
    log.log("ONE");
    expect(log.length, 1);
    expect(log.toString(), "ONE");
    log.log("TWO");
    expect(log.length, 2);
    expect(log.toString(), "ONE\n\nTWO");
    log.log("THREE");
    expect(log.length, 3);
    expect(log.toString(), "ONE\n\nTWO\n\nTHREE");
    log.log("FOUR");
    expect(log.length, 3);
    expect(log.toString(), "TWO\n\nTHREE\n\nFOUR");
    log.log("FIVE");
    expect(log.length, 3);
    expect(log.toString(), "THREE\n\nFOUR\n\nFIVE");
  });

  test('Test do not log same line twice', () async {
    final log = Logger(3, true);
    expect(log.length, 0);
    expect(log.toString(), "");
    log.log("ONE");
    expect(log.length, 1);
    expect(log.toString(), "ONE");
    log.log("TWO");
    expect(log.length, 2);
    expect(log.toString(), "ONE\n\nTWO");
    log.log("TWO");
    expect(log.length, 2);
    expect(log.toString(), "ONE\n\nTWO");
    log.log("TWO");
    expect(log.length, 2);
    expect(log.toString(), "ONE\n\nTWO");
    log.log("TWO");
    expect(log.length, 2);
    expect(log.toString(), "ONE\n\nTWO");
  });
}
