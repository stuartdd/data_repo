import 'package:data_repo/data_load.dart';
import 'package:data_repo/treeNode.dart';
import 'package:data_repo/path.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert' as json_tools;

void main() {
  void verifyNodeProperties(final MyTreeNode tn, String dotPath, int pathLen, bool empty, canExpand, hasLeaf, hasMap, isLeaf) {
    final p = Path.fromDotPath(dotPath);
    final n = tn.findByPath(p);
    if (n == null) {
      fail("Node at dotPath $dotPath returned was null");
    }
    expect(n.path.toString(), dotPath);
    expect(n.label, p.last);
    expect(n.pathKey, p.last);
    expect(n.pathLen, pathLen);
    expect(n.expanded, true);
    if (n.canExpand) {
      if (n.expanded) {
        expect(n.iconIndex, 1);
        n.expanded = false;
        expect(n.iconIndex, 2);
        n.expanded = false;
      } else {
        expect(n.iconIndex, 2);
      }
    }
    expect(n.isRoot, false);
    if (p.length > 1) {
      expect(n.parent!.pathKey, p.cloneParentPath().last);
    } else {
      expect(n.parent!.pathKey, "");
    }
    expect(n.isEmpty, empty);
    expect(n.isNotEmpty, !empty);
    expect(n.canExpand, canExpand);
    expect(n.hasLeafNodes, hasLeaf);
    expect(n.hasMapNodes, hasMap);
    expect(n.isLeaf, isLeaf);
    expect(n.isNotLeaf, !isLeaf);
  }
//  void verifyNodeProperties(final MyTreeNode tn, String dotPath, int pathLen, bool empty, canExpand, hasLeaf, hasMap, isLeaf) {
  test('Test Can Expand', () async {
    final s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/data06.json").value);
    // Test original and clone are the same.
    final m = MyTreeNode.fromMap(s);
    verifyNodeProperties(m, "A", 1, false, true, false, true, false);
    verifyNodeProperties(m, "A.A1", 2, false, true, false, true, false);
    verifyNodeProperties(m, "A.A1.A11", 3, false, false, true, false, false);
    verifyNodeProperties(m, "A.A1.A11.A111", 4, true, false, false, false, true);
    verifyNodeProperties(m, "A.B", 2, false, true, false, true, false);
    verifyNodeProperties(m, "A.B.B2", 3, false, true, true, true, false);
    verifyNodeProperties(m, "A.B.B2.B21", 4, false, false, true, false, false);
    verifyNodeProperties(m, "A.B.B2.B3", 4, true, false, false, false, true);
    verifyNodeProperties(m, "C", 1, true, false, false, false, false);
  });

  const expectFull = "A(1)R A.A1(2)R A.A1.A11(3)R A.A1.A11.A111(4)LR A.A1.A11.A112(4)LR A.B(2)R A.B.B1(3)R A.B.B1.B11(4)LR A.B.B1.B12(4)LR A.B.B2(3)R A.B.B2.B21(4)R A.B.B2.B21.B211(5)LR A.B.B2.B21.B212(5)LR C(1)R";
  const expectA111NotReq = "A(1)R A.A1(2)R A.A1.A11(3)R A.A1.A11.A111(4)L A.A1.A11.A112(4)LR A.B(2)R A.B.B1(3)R A.B.B1.B11(4)LR A.B.B1.B12(4)LR A.B.B2(3)R A.B.B2.B21(4)R A.B.B2.B21.B211(5)LR A.B.B2.B21.B212(5)LR C(1)R";
  const expectWithoutA111 = "A(1)R A.A1(2)R A.A1.A11(3)R A.A1.A11.A112(4)LR A.B(2)R A.B.B1(3)R A.B.B1.B11(4)LR A.B.B1.B12(4)LR A.B.B2(3)R A.B.B2.B21(4)R A.B.B2.B21.B211(5)LR A.B.B2.B21.B212(5)LR C(1)R";
  void toStrTest(final MyTreeNode n, String expected) {
    StringBuffer sb = StringBuffer();
    n.visitEachSubNode((node) {
      sb.write(node.path.toString());
      sb.write("(");
      sb.write(node.pathLen);
      sb.write(")");
      if (node.isLeaf) {
        sb.write('L');
      }
      if (node.isRequired) {
        sb.write('R');
      }
      sb.write(" ");
    });
    expect(sb.toString().trim(), expected);
  }

  test('Test Filtered and cloned ', () async {
    final s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/data04.json").value);
    // Test original and clone are the same.
    final m = MyTreeNode.fromMap(s);
    toStrTest(m, expectFull);
    final mc = m.clone();
    toStrTest(mc, expectFull);

    // Test clone with A111 not required
    // And that originals are not changed.
    final a111 = mc.findByPath(Path.fromDotPath("A.A1.A11.A111"));
    a111!.setRequired(false);
    final mcc = mc.clone(requiredOnly: true);
    toStrTest(mcc, expectWithoutA111);
    toStrTest(mc, expectA111NotReq);
    toStrTest(m, expectFull);

    // Apply filter but always match so clone should be same.
    MyTreeNode mccf = mc.applyFilter(
      "12",
      true,
      (match, toLowerCase, node) {
        return true;
      },
    );
    toStrTest(mccf, expectFull);
    toStrTest(mc, expectFull);
    toStrTest(m, expectFull);

    // Apply filter but match ALL except A111 or a111.
    mccf = mc.applyFilter(
      "a111",
      true,
      (match, toLowerCase, node) {
        return (node.pathKey.toLowerCase() != match);
      },
    );
    toStrTest(mccf, expectWithoutA111);
    toStrTest(m, expectFull);
    mccf = mc.applyFilter(
      "A111",
      true,
      (match, toLowerCase, node) {
        return (node.pathKey.toLowerCase() != match);
      },
    );
    toStrTest(mccf, expectWithoutA111);
    toStrTest(m, expectFull);

    var mcff = mc.applyFilter(
      "b21",
      true,
      (match, toLowerCase, node) {
        return node.pathKey.toLowerCase().contains(match);
      },
    );
    toStrTest(mcff, "A(1)R A.B(2)R A.B.B2(3)R A.B.B2.B21(4)R A.B.B2.B21.B211(5)LR A.B.B2.B21.B212(5)LR");
    toStrTest(m, expectFull);

    mcff = mc.applyFilter(
      "A112",
      true,
      (match, toLowerCase, node) {
        return node.pathKey.toLowerCase().contains(match);
      },
    );
    toStrTest(mcff, "A(1)R A.A1(2)R A.A1.A11(3)R A.A1.A11.A112(4)LR");
    toStrTest(m, expectFull);

    mcff = mc.applyFilter(
      "C",
      true,
      (match, toLowerCase, node) {
        return node.pathKey.toLowerCase().contains(match);
      },
    );
    toStrTest(mcff, "C(1)R");
    toStrTest(m, expectFull);

    mcff = mc.applyFilter(
      "c",
      true,
      (match, toLowerCase, node) {
        return node.pathKey.toLowerCase().contains(match);
      },
    );
    toStrTest(mcff, "C(1)R");
    toStrTest(m, expectFull);

    mcff = mc.applyFilter(
      "C",
      false,
      (match, toLowerCase, node) {
        return node.pathKey.toLowerCase().contains(match);
      },
    );
    toStrTest(mcff, "");
    toStrTest(mc.clearFilter(), expectFull);
    toStrTest(m, expectFull);
  });

  test('Test from map + visitEach-*-Node ', () async {
    final s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/data04.json").value);
    final m = MyTreeNode.fromMap(s);
    toStrTest(m, expectFull);
    final n = m.findByPath(Path.fromDotPath("A.A1.A11.A111"));
    expect(n!.isLeaf, true);

    StringBuffer sb = StringBuffer();
    n.visitEachParentNode((node) {
      if (node.isRoot) {
        sb.write("root");
      } else {
        sb.write(node.label);
      }
      sb.write("|");
    });
    expect(sb.toString().trim(), "A11|A1|A|root|");

    sb.clear();
    m.visitEachLeafNode((node) {
      sb.write(node.path.toString());
      sb.write("(");
      sb.write(node.pathLen);
      sb.write(")");
      if (node.isLeaf) {
        sb.write('L');
      }
      sb.write(" ");
    });
    expect(sb.toString().trim(), "A.A1.A11.A111(4)L A.A1.A11.A112(4)L A.B.B1.B11(4)L A.B.B1.B12(4)L A.B.B2.B21.B211(5)L A.B.B2.B21.B212(5)L");
  });

  test('Test from map + findByPath ', () async {
    final s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/data04.json").value);
    final m = MyTreeNode.fromMap(s);

    final cc = m.findByPath(Path(['C']));
    expect('C', cc!.label);
    expect('C', cc.path.toString());

    final aa = m.findByPath(Path(['A']));
    expect('A', aa!.label);
    expect('A', aa.path.toString());

    final aa1 = m.findByPath(Path(['A', 'A1']));
    expect('A1', aa1!.label);
    expect('A.A1', aa1.path.toString());

    final aa111 = m.findByPath(Path(['A', 'A1', 'A11', 'A111']));
    expect('A111', aa111!.label);
    expect('A.A1.A11.A111', aa111.path.toString());

    final aa112 = m.findByPath(Path(['A', 'A1', 'A11', 'A112']));
    expect('A112', aa112!.label);
    expect('A.A1.A11.A112', aa112.path.toString());

    expect(null, m.findByPath(Path(['A', 'A1', 'A1X', 'A112'])));
    expect(null, m.findByPath(Path(['A', 'A1', 'A11', 'A113'])));
    expect(null, m.findByPath(Path(['Z', 'A1', 'A11', 'A113'])));
  });

  test('Test from map + findByLabel ', () async {
    final s = json_tools.jsonDecode(DataLoad.loadFromFile("test/data/data04.json").value);
    final m = MyTreeNode.fromMap(s);
    expect(logNode(m), "P:[A] L:A O:[]  P:[A.A1] L:A1 O:[A]    P:[A.A1.A11] L:A11 O:[A.A1]      P:[A.A1.A11.A111] L:A111 O:[A.A1.A11]      P:[A.A1.A11.A112] L:A112 O:[A.A1.A11]  P:[A.B] L:B O:[A]    P:[A.B.B1] L:B1 O:[A.B]      P:[A.B.B1.B11] L:B11 O:[A.B.B1]      P:[A.B.B1.B12] L:B12 O:[A.B.B1]    P:[A.B.B2] L:B2 O:[A.B]      P:[A.B.B2.B21] L:B21 O:[A.B.B2]        P:[A.B.B2.B21.B211] L:B211 O:[A.B.B2.B21]        P:[A.B.B2.B21.B212] L:B212 O:[A.B.B2.B21]P:[C] L:C O:[]");

    expect(null, m.parent);
    expect("", m.path.toString());
    expect("", m.label);
    expect(true, m.expanded);

    expect(null, m.findByLabel(''));
    expect(null, m.findByLabel('c'));

    final cc = m.findByLabel('C');
    expect('C', cc!.label);
    expect('C', cc.path.toString());
    expect(false, cc.isNotEmpty);
    expect(true, cc.isEmpty);
    expect(m, cc.parent);

    final aa = m.findByLabel('A');
    expect('A', aa!.label);
    expect('A', aa.path.toString());
    expect(true, aa.isNotEmpty);
    expect(true, aa.expanded);

    final aa1 = aa.findByLabel('A1');
    expect('A1', aa1!.label);
    expect('A.A1', aa1.path.toString());

    final aa11 = aa1.findByLabel('A11');
    expect('A11', aa11!.label);
    expect('A.A1.A11', aa11.path.toString());
    expect(true, aa11.isNotEmpty);
    expect(false, aa11.isEmpty);

    final aa111 = aa11.findByLabel('A111');
    expect('A111', aa111!.label);
    expect('A.A1.A11.A111', aa111.path.toString());
    expect(false, aa111.isNotEmpty);
    expect(true, aa111.isEmpty);
    final aa112 = aa11.findByLabel('A112');
    expect('A112', aa112!.label);
    expect('A.A1.A11.A112', aa112.path.toString());
    expect(false, aa112.isNotEmpty);
    expect(true, aa112.isEmpty);
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
