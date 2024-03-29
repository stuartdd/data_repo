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
import 'package:flutter_test/flutter_test.dart';

void main() {
  //

  test('Factory fromFileContent file who wins', () async {
    const sLow = "TS:E:9:{low}";
    const sHigh = "TS:E:11:{high}";
    const sErr1 = "TS:E:10:";
    const sErr2 = "TS:E:99:";

    final fLow = FileDataPrefix.fromFileContent(sLow, "low");
    expect(fLow.toString(), "true:9:7:true:false:low");
    expect(sLow.substring(fLow.startPos), "{low}");
    expect(fLow.content, "{low}");
    expect(fLow.tag, "low");

    final fHigh = FileDataPrefix.fromFileContent(sHigh, "high");
    expect(fHigh.toString(), "true:11:8:true:false:high");
    expect(sHigh.substring(fHigh.startPos), "{high}");
    expect(fHigh.content, "{high}");
    expect(fHigh.tag, "high");

    expect(fLow.selectWithNoErrorOrLatest(fHigh), fHigh);
    expect(fLow.selectWithNoErrorOrLatest(fHigh).content, "{high}");
    expect(fHigh.selectWithNoErrorOrLatest(fLow), fHigh);
    expect(fHigh.selectWithNoErrorOrLatest(fLow).content, "{high}");
    expect(fHigh.isEqual(fLow), false);

    final fError1 = FileDataPrefix.fromFileContent(sErr1, "err");
    expect(fError1.toString(), "false:0:0:false:true:No content");
    expect(fError1.content, "");
    expect(fError1.tag, "");
    final fError2 = FileDataPrefix.fromFileContent(sErr2, "err");
    expect(fError1.toString(), "false:0:0:false:true:No content");
    expect(fError2.content, "");
    expect(fError2.tag, "");

    expect(fLow.selectWithNoErrorOrLatest(fError1), fLow);
    expect(fLow.selectWithNoErrorOrLatest(fError1).content, "{low}");
    expect(fHigh.selectWithNoErrorOrLatest(fError1), fHigh);
    expect(fHigh.selectWithNoErrorOrLatest(fError1).content, "{high}");
    expect(fError1.selectWithNoErrorOrLatest(fLow), fLow);
    expect(fError1.selectWithNoErrorOrLatest(fLow).content, "{low}");
    expect(fError1.selectWithNoErrorOrLatest(fHigh), fHigh);
    expect(fError1.selectWithNoErrorOrLatest(fHigh).content, "{high}");

    expect(fError1.selectWithNoErrorOrLatest(fError2).toString(), "false:0:0:false:true:Cannot select file data");
    expect(fError2.selectWithNoErrorOrLatest(fError1).toString(), "false:0:0:false:true:Cannot select file data");

    expect(fError2.isEqual(fError1), true);
    expect(fError1.isEqual(fError1), true);
    expect(fHigh.isEqual(fLow), false);
    expect(fLow.isEqual(fHigh), false);

    expect(fHigh.isEqual(fError1), false);
    expect(fLow.isEqual(fError1), false);
    expect(fError1.isEqual(fLow), false);
    expect(fError1.isEqual(fHigh), false);
  });

  test('Factory fromFileContent empty', () async {
    final er = FileDataPrefix.fromFileContent("", "");
    expect(er.toString(), "false:0:0:false:true:No content");
  });

  test('Factory fromFileContent  OK ret enpty string', () async {
    const td = "TS:E:9:";
    final er = FileDataPrefix.fromFileContent(td, "err");
    expect(er.toString(), "false:0:0:false:true:No content");
  });

  test('Factory fromFileContent not equal or gt no prefix', () async {
    const td1 = "TS:E:9:{}";
    const td2 = "abc";
    final p1 = FileDataPrefix.fromFileContent(td1, "braces");
    final p2 = FileDataPrefix.fromFileContent(td2, "abc");
    expect(p1.toString(), "true:9:7:true:false:braces");
    expect(p2.toString(), "false:0:0:false:false:abc");
    expect(p1.isEqual(p2), false);
    expect(p1.selectWithNoErrorOrLatest(p2), p1);
    expect(p2.isEqual(p1), false);
    expect(p2.selectWithNoErrorOrLatest(p1), p1);
  });

  test('Factory fromFileContent not equal or gt error', () async {
    const td1 = "TS:E:9:{}";
    const td2 = "TS:E:10";
    final p1 = FileDataPrefix.fromFileContent(td1, "braces");
    final p2 = FileDataPrefix.fromFileContent(td2, "err");
    expect(p1.toString(), "true:9:7:true:false:braces");
    expect(p2.toString(), "false:0:0:false:true:No data after Timestamp");
    expect(p1.isEqual(p2), false);
    expect(p1.selectWithNoErrorOrLatest(p2), p1);
    expect(p2.isEqual(p1), false);
    expect(p2.selectWithNoErrorOrLatest(p1), p1);
  });

  test('Factory fromFileContent equal', () async {
    const td = "TS:E:9:{}";
    final p1 = FileDataPrefix.fromFileContent("xx", "xx");
    final p2 = FileDataPrefix.fromFileContent(td, "braces");
    expect(p1.toString(), "false:0:0:false:false:xx");
    expect(p2.toString(), "true:9:7:true:false:braces");
    expect(p1.isEqual(p2), false);
    expect(p1.selectWithNoErrorOrLatest(p2), p2);
    expect(p2.isEqual(p1), false);
    expect(p2.selectWithNoErrorOrLatest(p1), p2);
  });

  test('Factory fromFileContent equal', () async {
    const td = "TS:E:9:{}";
    final p1 = FileDataPrefix.fromFileContent(td, "braces1");
    final p2 = FileDataPrefix.fromFileContent(td, "braces2");
    expect(p1.toString(), "true:9:7:true:false:braces1");
    expect(p2.toString(), "true:9:7:true:false:braces2");
    expect(p1.isEqual(p2), true);
    expect(p1.selectWithNoErrorOrLatest(p2), p2);
    expect(p2.isEqual(p1), true);
    expect(p2.selectWithNoErrorOrLatest(p1), p1);
  });

  test('Factory fromFileContent OK', () async {
    const td = "TS:E:9:{}";
    final er = FileDataPrefix.fromFileContent(td, "braces");
    expect(er.toString(), "true:9:7:true:false:braces");
    expect(td.substring(er.startPos), "{}");
    expect(er.content, "{}");
  });

  test('Factory fromFileContent OK no : terminal', () async {
    const td = "TS:E:9g";
    final er = FileDataPrefix.fromFileContent(td, "g");
    expect(er.toString(), "true:9:6:true:false:g");
    expect(td.substring(er.startPos), "g");
  });

  test('Factory fromFileContent no data', () async {
    final er = FileDataPrefix.fromFileContent("TS:E:9", "err");
    expect(er.toString(), "false:0:0:false:true:No data after Timestamp");
  });

  test('Factory fromFileContent Invalid TS E', () async {
    final er = FileDataPrefix.fromFileContent("TS:E: ", "err");
    expect(er.toString(), "false:0:0:false:true:Invalid Timestamp");
  });

  test('Factory fromFileContent Invalid TS C', () async {
    final er = FileDataPrefix.fromFileContent("TS:C: ", "err");
    expect(er.toString(), "false:0:0:false:true:Invalid Timestamp");
  });

  test('Factory fromFileContent No TS data C', () async {
    final er = FileDataPrefix.fromFileContent("TS:C:", "err");
    expect(er.toString(), "false:0:0:false:true:No Timestamp data");
  });

  test('Factory fromFileContent No TS data E', () async {
    final er = FileDataPrefix.fromFileContent("TS:E:", "err");
    expect(er.toString(), "false:0:0:false:true:No Timestamp data");
  });

  test('Factory fromFileContent part prefix', () async {
    final er = FileDataPrefix.fromFileContent("TS", "TS");
    expect(er.toString(), "false:0:0:false:false:TS");
  });

  test('Factory fromFileContent noPrefix', () async {
    final er = FileDataPrefix.fromFileContent("abc", "abc");
    expect(er.toString(), "false:0:0:false:false:abc");
  });

  test('Factory noPrefix', () async {
    final er = FileDataPrefix.empty();
    expect(er.toString(), "false:0:0:false:false:empty");
  });

  test('Factory error', () async {
    final er = FileDataPrefix.error("error");
    expect(er.toString(), "false:0:0:false:true:error");
  });
}
