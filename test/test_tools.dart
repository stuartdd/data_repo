import 'package:flutter_test/flutter_test.dart';

assertContainsAll(List<String> list, String s) {
  for (var i = 0; i < list.length; i++) {
    if (!s.contains(list[i])) {
      fail("Message Text [$s] does not contain all of '${list[i]}'");
    }
  }
}

assertContainsNone(List<String> list, String s) {
  for (var i = 0; i < list.length; i++) {
    if (s.contains(list[i])) {
      fail("Message Text [$s] should not contain '${list[i]}'");;
    }
  }
}