/*
 * Copyright (C) 2023 Stuart Davies (stuartdd)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
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
    expect(log.toString(), "ONE\n\n2 TWO");
    log.log("TWO");
    expect(log.length, 2);
    expect(log.toString(), "ONE\n\n3 TWO");
    log.log("TWO");
    expect(log.length, 2);
    expect(log.toString(), "ONE\n\n4 TWO");
  });
}
