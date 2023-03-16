import 'package:flutter_test/flutter_test.dart';
import 'package:data_repo/path.dart';

void main() {
  //
  test('Test Clone Append', () async {
    final p = Path.fromDotPath("root.one.two");
    expect(p.length(), 3);
    expect(p.toString(), "root.one.two");
    final p2 = p.cloneAppend(["three","four"]);
    expect(p.length(), 3);
    expect(p.toString(), "root.one.two");
    expect(p2.length(), 5);
    expect(p2.toString(), "root.one.two.three.four");

    expect(p.pop(), "two");
    expect(p2.pop(), "four");
    expect(p.length(), 2);
    expect(p.toString(), "root.one");
    expect(p2.length(), 4);
    expect(p2.toString(), "root.one.two.three");

    final p3 = Path.fromDotPath("root.one.two");
    expect(p3.length(), 3);
    expect(p3.toString(), "root.one.two");
    final p4 = p3.cloneAppend(["three","four"]);
    p4.push("five");
    p4.push("six");
    expect(p4.toString(), "root.one.two.three.four.five.six");

  });


  test('Test Path Peek and Last', () async {
    final p = Path.fromDotPath("root.one.two");
    expect(p.length(), 3);
    expect(p.getRoot(), "root");
    expect(p.peek(-1), "");
    expect(p.peek(0), "root");
    expect(p.peek(1), "one");
    expect(p.peek(2), "two");
    expect(p.peek(3), "");
    expect(p.toString(), "root.one.two");
    expect(p.getLast(), "two");
    expect(p.isEmpty(), false);
    expect(p.isNotEmpty(), true);

    expect(p.pop(), "two");
    expect(p.toString(), "root.one");
    expect(p.getLast(), "one");
    expect(p.isEmpty(), false);
    expect(p.isNotEmpty(), true);
    expect(p.pop(), "one");

    expect(p.toString(), "root");
    expect(p.getLast(), "root");
    expect(p.isEmpty(), false);
    expect(p.isNotEmpty(), true);
    expect(p.pop(), "root");

    assertEmpty(p);
    expect(p.getLast(), "");
    expect(p.getRoot(), "");
  });

  test('Test Path From String and isInMap', () async {
    final p = Path.fromDotPath("root.one.two");
    expect(p.length(), 3);
    expect(p.getRoot(), "root");
    expect(p.toString(), "root.one.two");
    expect(p.isEmpty(), false);
    expect(p.isNotEmpty(), true);

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
    expect(p.length(), 1);
    expect(p.getRoot(), "root");
    expect(p.toString(), "root");
    expect(p.isEmpty(), false);
    expect(p.isNotEmpty(), true);
    expect(p.pop(), "root");
    assertEmpty(p);
    expect(p.pop(), "");
    assertEmpty(p);

    p.push("root");
    p.push("one");
    p.push("two");

    expect(p.length(), 3);
    expect(p.getRoot(), "root");
    expect(p.toString(), "root.one.two");
    expect(p.isEmpty(), false);
    expect(p.isNotEmpty(), true);

    expect(p.pop(), "two");
    expect(p.length(), 2);
    expect(p.getRoot(), "root");
    expect(p.toString(), "root.one");
    expect(p.isEmpty(), false);
    expect(p.isNotEmpty(), true);

    expect(p.pop(), "one");
    expect(p.length(), 1);
    expect(p.getRoot(), "root");
    expect(p.toString(), "root");
    expect(p.isEmpty(), false);
    expect(p.isNotEmpty(), true);

    expect(p.pop(), "root");
    assertEmpty(p);
    expect(p.pop(), "");
    assertEmpty(p);
  });
}

void assertEmpty(Path p) {
  expect(p.length(), 0);
  expect(p.getRoot(), "");
  expect(p.toString(), "");
  expect(p.isEmpty(), true);
  expect(p.isNotEmpty(), false);
  expect(p.pop(), "");
}
