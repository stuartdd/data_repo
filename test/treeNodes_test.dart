import 'package:data_repo/data_load.dart';
import 'package:data_repo/treeNode.dart';
import 'package:data_repo/path.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert' as json_tools;

void main() {

  test('Test from map + visitEachNode ', () async {
    final s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/data04.json").value);
    final m = MyTreeNode.fromMap(s);
    StringBuffer sb = StringBuffer();
    m.visitEachNode((node) {
      sb.write(node.path.toString());
      sb.write("(");
      sb.write(node.pathLen);
      sb.write(") ");
    });
//    debugPrint(sb.toString());
    expect(sb.toString().trim(),"A(1) A.A1(2) A.A1.A11(3) A.A1.A11.A111(4) A.A1.A11.A112(4) A.B(2) A.B.B1(3) A.B.B1.B11(4) A.B.B1.B12(4) A.B.B2(3) A.B.B2.B21(4) A.B.B2.B21.B211(5) A.B.B2.B21.B212(5) C(1)");
  });

  test('Test from map + findByPath ', () async {
    final s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/data04.json").value);
    final m = MyTreeNode.fromMap(s);

    final cc = m.findByPath(Path(['C']));
    expect('C', cc!.label);
    expect('C', cc!.path.toString());

    final aa = m.findByPath(Path(['A']));
    expect('A', aa!.label);
    expect('A', aa!.path.toString());

    final aa1 = m.findByPath(Path(['A', 'A1']));
    expect('A1', aa1!.label);
    expect('A.A1', aa1!.path.toString());

    final aa111 = m.findByPath(Path(['A', 'A1', 'A11', 'A111']));
    expect('A111', aa111!.label);
    expect('A.A1.A11.A111', aa111!.path.toString());

    final aa112 = m.findByPath(Path(['A', 'A1', 'A11', 'A112']));
    expect('A112', aa112!.label);
    expect('A.A1.A11.A112', aa112!.path.toString());

    expect(null, m.findByPath(Path(['A', 'A1', 'A1X', 'A112'])));
    expect(null, m.findByPath(Path(['A', 'A1', 'A11', 'A113'])));
    expect(null, m.findByPath(Path(['Z', 'A1', 'A11', 'A113'])));
  });

  test('Test from map + findByLabel ', () async {
    final s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/data04.json").value);
    final m = MyTreeNode.fromMap(s);
    expect(logNode(m), "P:[A] L:A O:[]  P:[A.A1] L:A1 O:[A]    P:[A.A1.A11] L:A11 O:[A.A1]      P:[A.A1.A11.A111] L:A111 O:[A.A1.A11]      P:[A.A1.A11.A112] L:A112 O:[A.A1.A11]  P:[A.B] L:B O:[A]    P:[A.B.B1] L:B1 O:[A.B]      P:[A.B.B1.B11] L:B11 O:[A.B.B1]      P:[A.B.B1.B12] L:B12 O:[A.B.B1]    P:[A.B.B2] L:B2 O:[A.B]      P:[A.B.B2.B21] L:B21 O:[A.B.B2]        P:[A.B.B2.B21.B211] L:B211 O:[A.B.B2.B21]        P:[A.B.B2.B21.B212] L:B212 O:[A.B.B2.B21]P:[C] L:C O:[]");
// debugPrint(logNode(m));
    expect(null, m.parent);
    expect("", m.path.toString());
    expect("", m.label);
    expect(false, m.expanded);

    expect(null, m.findByLabel(''));
    expect(null, m.findByLabel('c'));

    final cc = m.findByLabel('C');
    expect('C', cc!.label);
    expect('C', cc!.path.toString());
    expect(false, cc!.isNotEmpty);
    expect(true, cc!.isEmpty);
    expect(m, cc!.parent);

    final aa = m.findByLabel('A');
    expect('A', aa!.label);
    expect('A', aa!.path.toString());
    expect(true, aa!.isNotEmpty);
    expect(false, aa!.expanded);

    final aa1 = aa!.findByLabel('A1');
    expect('A1', aa1!.label);
    expect('A.A1', aa1!.path.toString());

    final aa11 = aa1!.findByLabel('A11');
    expect('A11', aa11!.label);
    expect('A.A1.A11', aa11!.path.toString());
    expect(true, aa11!.isNotEmpty);
    expect(false, aa11!.isEmpty);

    final aa111 = aa11!.findByLabel('A111');
    expect('A111', aa111!.label);
    expect('A.A1.A11.A111', aa111!.path.toString());
    expect(false, aa111!.isNotEmpty);
    expect(true, aa111!.isEmpty);
    final aa112 = aa11!.findByLabel('A112');
    expect('A112', aa112!.label);
    expect('A.A1.A11.A112', aa112!.path.toString());
    expect(false, aa112!.isNotEmpty);
    expect(true, aa112!.isEmpty);
  });
}

const String tabs = "                                                                                 ";
String logNode(MyTreeNode n) {
  final StringBuffer sb = StringBuffer();
  _logNodeR(n, sb, 0);
  return sb.toString().trim();
}

void _logNodeR(MyTreeNode n, StringBuffer sb, int tab) {
  for (MyTreeNode x in n.children) {
    sb.write("${tabs.substring(0, tab * 2)}P:[${x.path.toString()}] L:${x.label} O:[${x.parent == null ? 'null' : x.parent!.path}]");
    _logNodeR(x, sb, tab + 1);
  }
}
