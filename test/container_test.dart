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

import 'package:data_repo/data_container.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:data_repo/path.dart';
import 'package:data_repo/data_types.dart';

const someJson = """  {
        "data" : {
            "intNode": 5,
            "decimalNode": 5.1,
            "boolNode": true,
            "text": "test"
        },
        "more" : {
           "moreBool": true,
           "moreText": "test"        
        },
        "file": {
            "serverPath": "http://192.168.1.243:8080",
            "datafileName": "data.json",
            "datafilePath": "."
        }
    } """;

const replace1 = {"Hi": 2};

void main() {
  test('Test Remove', () async {
    final c = DataContainer.fromJson(someJson);
    expect(c.dataMap is Map<String, dynamic>, true);
    expect(c.getNodeFromJson(Path.fromDotPath("data.decimalNode")), 5.1);
    expect(c.remove(Path.fromDotPath("data.decimalNode"), dryRun: true), "");
    expect(c.remove(Path.fromDotPath("data.node"), dryRun: true), "Remove: cannot find node");
    expect(c.getNodeFromJson(Path.fromDotPath("data.decimalNode")), 5.1);
    expect(c.remove(Path.fromDotPath("data.decimalNode"), dryRun: false), "");
    expect(c.getNodeFromJson(Path.fromDotPath("data.decimalNode")), null);
    final more = c.getNodeFromJson(Path.fromDotPath("more"));
    expect("$more","{moreBool: true, moreText: test}");
    expect(c.remove(Path.fromDotPath("more"), dryRun: false), "Remove: cannot remove root node");
  });


  test('Test Replace', () async {
    final c = DataContainer.fromJson(someJson);
    expect(c.dataMap is Map<String, dynamic>, true);
    expect(c.replace(Path.fromDotPath("data.decimal"), true, dryRun: true), "Replace: Node not found");
    expect(c.replace(Path.fromDotPath("data"), true, dryRun: true), "Replace: Cannot replace root");
    expect(c.replace(Path.fromDotPath("data.decimalNode"), true, dryRun: true), "");
    expect(c.getNodeFromJson(Path.fromDotPath("data.decimalNode")), 5.1);
    expect(c.replace(Path.fromDotPath("data.decimalNode"), true, dryRun: false), "");
    expect(c.getNodeFromJson(Path.fromDotPath("data.decimalNode")), true);
    expect(c.replace(Path.fromDotPath("data.decimalNode"), replace1, dryRun: false), "");
    expect(c.getNodeFromJson(Path.fromDotPath("data.decimalNode")), replace1);
    final nullData = c.getNodeFromJson(Path.fromDotPath("data.more"));
    expect(c.replace(Path.fromDotPath("data.decimalNode"), nullData, dryRun: false), "Replace: Cannot replace with null");
    final more = c.getNodeFromJson(Path.fromDotPath("more"));
    expect("$more","{moreBool: true, moreText: test}");
    expect(c.replace(Path.fromDotPath("data.decimalNode"), more, dryRun: false), "");
    final dn = c.getNodeFromJson(Path.fromDotPath("data.decimalNode"));
    expect("$dn","{moreBool: true, moreText: test}");
  });

  test('Test Add', () async {
    final c = DataContainer.fromJson(someJson);
    expect(c.dataMap is Map<String, dynamic>, true);
    expect(c.add(Path.fromDotPath("data"), "newNode", true, dryRun: true), "");
    expect(c.add(Path.fromDotPath("data"), "newNode", true, dryRun: false), "");
    expect(c.getNodeFromJson(Path.fromDotPath("data.newNode")), true);
    expect(c.add(Path.fromDotPath("data"), "newNode", true, dryRun: false), "Add: Name already exists");

    expect(c.add(Path.fromDotPath("data.text"), "ff", 5, dryRun: false), "Add: Parent node not a Map");

    expect(c.add(Path.fromDotPath("data"), "x", 5, dryRun: false), "Add: Is too short");
    expect(c.add(Path.fromDotPath("data"), "x$pathSeparator", 4, dryRun: false), "Add: Cannot contain '$pathSeparator'");
    expect(c.add(Path.fromDotPath("data"), "x$extensionSeparator", 3, dryRun: false), "Add: Cannot contain '$extensionSeparator'");

    final Map<String, dynamic> m = {"Hi": 2};
    expect(c.add(Path.fromDotPath("data"), "data", m, dryRun: false), "");
    expect(c.getNodeFromJson(Path.fromDotPath("data.data")), {'Hi': 2});
    expect(c.getNodeFromJson(Path.fromDotPath("data.data.Hi")), 2);

    expect(
        c.add(Path.fromDotPath("data"), "notValid", 99.9, extension: ":XX", dryRun: false, validate: (parent, name, ext, val) {
          return ("${parent.length} $name $ext $val");
        }),
        "Add: 6 notValid :XX 99.9");
  });

  test('Test Rename', () async {
    final c = DataContainer.fromJson(someJson);
    expect(c.dataMap is Map<String, dynamic>, true);
    expect(c.getNodeFromJson(Path.fromDotPath("data.intNode")), 5);
    expect(c.getNumFromJson(Path.fromDotPath("data.intNode")), 5);

    expect(c.getNodeFromJson(Path.fromDotPath("data.decimalNode")), 5.1);
    expect(c.getNumFromJson(Path.fromDotPath("data.decimalNode")), 5.1);

    expect(c.getNodeFromJson(Path.fromDotPath("data.boolNode")), true);
    expect(c.getBoolFromJson(Path.fromDotPath("data.boolNode")), true);

    expect(c.getNodeFromJson(Path.fromDotPath("data.text")), "test");
    expect(c.getStringFromJson(Path.fromDotPath("data.text")), "test");
    expect(c.getStringFromJsonOptional(Path.fromDotPath("data.text")), "test");
    expect(c.getStringFromJsonOptional(Path.fromDotPath("data.xxxx")), "");

    expect(c.rename(Path.fromDotPath("data"), "xxc", dryRun: true), "Rename: Cannot rename root");
    expect(c.rename(Path.fromDotPath("data.boolNode"), "decimalNode", dryRun: true), "Rename: Name already exists");
    expect(c.rename(Path.fromDotPath("data.boolNode"), "decimalNode", extension: positionalStringExtension, dryRun: true), "Rename: Name already exists");
    expect(c.rename(Path.fromDotPath("data.boolNode"), "boolNode", dryRun: true), "Rename: Name already exists");
    expect(c.rename(Path.fromDotPath("data.boolNode"), "boolNode", extension: positionalStringExtension, dryRun: true), "Rename: Name already exists");
    expect(c.rename(Path.fromDotPath("data.boolNode"), "boolNodeX", dryRun: true), "");
    expect(c.rename(Path.fromDotPath("data.boolNode"), "boolNodeX", extension: positionalStringExtension, dryRun: true), "");
    expect(c.rename(Path.fromDotPath("data.boolNode"), "boolNodeX", dryRun: false), "");
    expect(c.rename(Path.fromDotPath("data.boolNode"), "boolNodeX", extension: positionalStringExtension, dryRun: true), "Rename: Name already exists");
    expect(c.rename(Path.fromDotPath("data.boolNode"), "boolNodeX", extension: positionalStringExtension, dryRun: false), "Rename: Name already exists");
    expect(c.getNodeFromJson(Path.fromDotPath("data.boolNodeX")), true);

    expect(c.rename(Path.fromDotPath("data.boolNodeX"), "x", dryRun: false), "Rename: Is too short");
    expect(c.rename(Path.fromDotPath("data.boolNodeX"), "x$pathSeparator", dryRun: false), "Rename: Cannot contain '$pathSeparator'");
    expect(c.rename(Path.fromDotPath("data.boolNodeX"), "x$extensionSeparator", dryRun: false), "Rename: Cannot contain '$extensionSeparator'");
    expect(c.rename(Path.fromDotPath("data.boolNodeX"), "xx", extension: positionalStringExtension, dryRun: true), "");
    expect(c.rename(Path.fromDotPath("data.boolNodeX"), "xx", extension: positionalStringExtension, dryRun: false), "");
    expect(c.getNodeFromJson(Path.fromDotPath("data.xx$positionalStringExtension")), true);
    expect(c.rename(Path.fromDotPath("data.boolNodeX"), "xx", dryRun: false), "Rename: Node not found");
    expect(c.getNodeFromJson(Path.fromDotPath("data.xx$positionalStringExtension")), true);
    expect(c.rename(Path.fromDotPath("data.xx$positionalStringExtension"), "xx", dryRun: false), "");
    expect(c.getNodeFromJson(Path.fromDotPath("data.xx")), true);
    expect(
        c.rename(Path.fromDotPath("data.xx"), "boolNode", extension: ":EX", dryRun: false, validate: (node, n, e) {
          return "$node $n $e";
        }),
        "Rename: true boolNode :EX");
    expect(c.getNodeFromJson(Path.fromDotPath("data.xx")), true);
  });
}
