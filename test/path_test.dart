import 'package:data_repo/data_load.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:data_repo/path.dart';
import 'dart:convert' as json_tools;

void main() {
  //
  test('Test Path Nodes', () async {
    var s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/data04.json").value);
    var p = PathNodes.from(s, Path.empty());
    expect(p.error, true);
    expect(p.isNotEmpty, false);
    expect(p.isEmpty, true);
    expect(p.length, 0);
    expect(p.lastNodeAsMap, null);
    expect(p.lastNodeHasParent, false);
    expect(p.lastNodeParent, null);
    expect(p.lastNodeIsMap, false);
    expect(p.lastNodeIsData, false);
    expect(p.toString(), "Error:");

    p = PathNodes.from(s, Path.fromDotPath('A'));
    expect(p.error, false);
    expect(p.isNotEmpty, true);
    expect(p.isEmpty, false);
    expect(p.length, 1);
    expect(p.lastNodeIsMap, true);
    expect(p.lastNodeIsData, false);
    expect(p.lastNodeHasParent, false);
    expect(p.lastNodeParent, null);
    Map<String, dynamic>? pm = p.lastNodeAsMap;
    expect(pm == null, false);
    expect(pm!.length, 2);

    p = PathNodes.from(s, Path.fromDotPath('A.X'));
    expect(p.error, true);
    expect(p.isNotEmpty, true);
    expect(p.isEmpty, false);
    expect(p.length, 1);
    expect(p.lastNodeIsMap, true);
    expect(p.lastNodeIsData, false);
    expect(p.lastNodeParent, null);
    pm = p.lastNodeAsMap;
    expect(pm == null, false);
    expect(pm!.length, 2);

    p = PathNodes.from(s, Path.fromDotPath('A.B'));
    expect(p.error, false);
    expect(p.isNotEmpty, true);
    expect(p.isEmpty, false);
    expect(p.length, 2);
    expect(p.lastNodeIsMap, true);
    expect(p.lastNodeIsData, false);
    pm = p.lastNodeAsMap;
    expect(p.lastNodeHasParent, true);
    Map<String, dynamic>? parent = p.lastNodeParent;
    expect(parent?.containsKey("B"), true);
    expect(parent?.containsKey("A1"), true);
    expect(parent == null, false);
    expect(pm == null, false);
    expect(pm!.length, 2);

    p = PathNodes.from(s, Path.fromDotPath('A.A1.A11.A111'));
    expect(p.error, false);
    expect(p.isNotEmpty, true);
    expect(p.isEmpty, false);
    expect(p.length, 4);
    expect(p.lastNodeIsMap, false);
    expect(p.lastNodeIsData, true);
    expect(p.lastNodeHasParent, true);
    parent = p.lastNodeParent;
    expect(parent == null, false);
    expect(parent?.containsKey("A111"), true);
    expect(parent?.containsKey("A112"), true);
    expect(parent?["A111"], "A111V");
    final ps = p.lastNodeAsData;
    expect(ps == null, false);
    expect(ps is String, true);
  });

  test('Test Clone Append, Parent, Reverse', () async {
    final p = Path.fromDotPath("root.one.two");
    expect(p.length, 3);
    expect(p.toString(), "root.one.two");
    final p2 = p.cloneAppendList(["three", "four"]);
    expect(p.length, 3);
    expect(p.toString(), "root.one.two");
    expect(p2.length, 5);
    expect(p2.toString(), "root.one.two.three.four");

    expect(p.pop(), "two");
    expect(p2.pop(), "four");
    expect(p.length, 2);
    expect(p.toString(), "root.one");
    expect(p2.length, 4);
    expect(p2.toString(), "root.one.two.three");

    final p3 = Path.fromDotPath("root.one.two");
    expect(p3.length, 3);
    expect(p3.toString(), "root.one.two");
    final p4 = p3.cloneAppendList(["three", "four"]);
    p4.push("five");
    p4.push("six");
    expect(p4.toString(), "root.one.two.three.four.five.six");
    var p5 = p4.cloneParentPath();
    expect(p4.toString(), "root.one.two.three.four.five.six");
    expect(p5.toString(), "root.one.two.three.four.five");
    p5 = p5.cloneParentPath();
    expect(p5.toString(), "root.one.two.three.four");
    p5 = p5.cloneParentPath();
    expect(p5.toString(), "root.one.two.three");
    p5 = p5.cloneParentPath();
    expect(p5.toString(), "root.one.two");
    p5 = p5.cloneParentPath();
    expect(p5.toString(), "root.one");
    p5 = p5.cloneParentPath();
    expect(p5.toString(), "root");
    p5 = p5.cloneParentPath();
    expect(p5.toString(), "");
    expect(p4.toString(), "root.one.two.three.four.five.six");
    final p6 = Path.fromDotPath("A.B.C");
    expect(p6.toString(), "A.B.C");
    final p7 = p6.cloneReversed();
    expect(p7.toString(), "C.B.A");
  });

  test('Test Path Peek and Last', () async {
    final p = Path.fromDotPath("root.one.two");
    expect(p.length, 3);
    expect(p.root, "root");
    expect(p.peek(-1), "");
    expect(p.peek(0), "root");
    expect(p.peek(1), "one");
    expect(p.peek(2), "two");
    expect(p.peek(3), "");
    expect(p.toString(), "root.one.two");
    expect(p.last, "two");
    expect(p.isEmpty, false);
    expect(p.isNotEmpty, true);

    expect(p.pop(), "two");
    expect(p.toString(), "root.one");
    expect(p.last, "one");
    expect(p.isEmpty, false);
    expect(p.isNotEmpty, true);
    expect(p.pop(), "one");

    expect(p.toString(), "root");
    expect(p.last, "root");
    expect(p.isEmpty, false);
    expect(p.isNotEmpty, true);
    expect(p.pop(), "root");

    assertEmpty(p);
    expect(p.last, "");
    expect(p.root, "");

    final px = Path.fromDotPath("root.one.two");
    expect(px.last, "two");
    px.setLast('xx');
    expect(px.last, "xx");
    expect(px.toString(), "root.one.xx");
    final px1 = px.cloneParentPath();
    expect(px1.toString(), "root.one");
    px1.setLast('yy');
    expect(px1.last, "yy");
    expect(px1.toString(), "root.yy");
    final px2 = px1.cloneParentPath();
    expect(px2.toString(), "root");
    px2.setLast('zz');
    expect(px2.last, "zz");
    expect(px2.toString(), "zz");
    final px3 = px2.cloneParentPath();
    expect(px3.toString(), "");
    px3.setLast("last");
    expect(px3.toString(), "last");
  });

  test('Test Path From String and isInMap', () async {
    final p = Path.fromDotPath("root.one.two");
    expect(p.length, 3);
    expect(p.root, "root");
    expect(p.toString(), "root.one.two");
    expect(p.isEmpty, false);
    expect(p.isNotEmpty, true);

    var m1 = {
      'root': {
        'one': {
          'two': {'a': 'b'}
        }
      }
    };
    expect(p.isInMap(m1), true);
    p.pop();
    expect(p.isInMap(m1), true);
    p.pop();
    expect(p.isInMap(m1), true);
    p.pop();
    expect(p.isInMap(m1), false);

    final p2 = Path.fromDotPath("root.one.none");
    expect(p2.isInMap(m1), false);
    p2.pop();
    expect(p2.isInMap(m1), true);

    final p3 = Path.fromDotPath("root.none.none");
    expect(p3.isInMap(m1), false);
    p3.pop();
    expect(p3.isInMap(m1), false);
    p3.pop();
    expect(p3.isInMap(m1), true);

    final p4 = Path.fromDotPath("none.none.none");
    expect(p4.isInMap(m1), false);

    final p5 = Path.fromDotPath("root.one.two.three");
    expect(p5.isInMap(m1), false);
  });

  test('Test Path Push Pop', () async {
    final p = Path.empty();
    assertEmpty(p);
    p.push("root");
    expect(p.length, 1);
    expect(p.root, "root");
    expect(p.toString(), "root");
    expect(p.isEmpty, false);
    expect(p.isNotEmpty, true);
    expect(p.pop(), "root");
    assertEmpty(p);
    expect(p.pop(), "");
    assertEmpty(p);

    p.push("root");
    p.push("one");
    p.push("two");

    expect(p.length, 3);
    expect(p.root, "root");
    expect(p.toString(), "root.one.two");
    expect(p.isEmpty, false);
    expect(p.isNotEmpty, true);

    expect(p.pop(), "two");
    expect(p.length, 2);
    expect(p.root, "root");
    expect(p.toString(), "root.one");
    expect(p.isEmpty, false);
    expect(p.isNotEmpty, true);

    expect(p.pop(), "one");
    expect(p.length, 1);
    expect(p.root, "root");
    expect(p.toString(), "root");
    expect(p.isEmpty, false);
    expect(p.isNotEmpty, true);

    expect(p.pop(), "root");
    assertEmpty(p);
    expect(p.pop(), "");
    assertEmpty(p);
  });
}

void assertEmpty(Path p) {
  expect(p.length, 0);
  expect(p.root, "");
  expect(p.toString(), "");
  expect(p.isEmpty, true);
  expect(p.isNotEmpty, false);
  expect(p.pop(), "");
}
