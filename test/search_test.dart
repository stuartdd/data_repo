import 'package:data_repo/data_load.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert' as json_tools;

void main() {
  test('Test Search Filtered', () async {
    final StringBuffer sb = StringBuffer();
    try {
      final s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/data02.json").value);
      DataLoad.pathsForMapNodes(
        s,
        (key) {
          if (key.contains("S1")) {
            sb.write(key);
            sb.write(', ');
          }
        },
      );
    } catch (e) {
      fail("threw an exception. Got $e ${e.runtimeType.toString()}");
    }
    expect(sb.toString(), 'Stuart|S1, Stuart|S1|S1A1, Stuart|S1|S1A2, Stuart|S1|S1A2|S1A2M1, ');
  });

  test('Test Search Basic', () async {
    final StringBuffer sb = StringBuffer();
    try {
      final s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/data01.json").value);
      DataLoad.pathsForMapNodes(
        s,
        (key) {
          sb.write(key);
          sb.write(', ');
        },
      );
    } catch (e) {
      fail("threw an exception. Got $e ${e.runtimeType.toString()}");
    }
    expect(sb.toString(), 'Stuart, Stuart|Data1, Stuart|Data1|App1, Stuart|Data1|App2, Roger, Roger|Data2, Roger|Data2|App3, Roger|Data2|App4, ');
  });
}
