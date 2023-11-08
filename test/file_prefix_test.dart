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

    expect(fLow.selectThisOrThat(fHigh), fHigh);
    expect(fLow.selectThisOrThat(fHigh).content, "{high}");
    expect(fHigh.selectThisOrThat(fLow), fHigh);
    expect(fHigh.selectThisOrThat(fLow).content, "{high}");
    expect(fHigh.isEqual(fLow), false);

    final fError1 = FileDataPrefix.fromFileContent(sErr1, "err");
    expect(fError1.toString(), "false:0:0:false:true:No content");
    expect(fError1.content, "");
    expect(fError1.tag, "");
    final fError2 = FileDataPrefix.fromFileContent(sErr2, "err");
    expect(fError1.toString(), "false:0:0:false:true:No content");
    expect(fError2.content, "");
    expect(fError2.tag, "");

    expect(fLow.selectThisOrThat(fError1), fLow);
    expect(fLow.selectThisOrThat(fError1).content, "{low}");
    expect(fHigh.selectThisOrThat(fError1), fHigh);
    expect(fHigh.selectThisOrThat(fError1).content, "{high}");
    expect(fError1.selectThisOrThat(fLow), fLow);
    expect(fError1.selectThisOrThat(fLow).content, "{low}");
    expect(fError1.selectThisOrThat(fHigh), fHigh);
    expect(fError1.selectThisOrThat(fHigh).content, "{high}");

    expect(fError1.selectThisOrThat(fError2).toString(), "false:0:0:false:true:Cannot select file data");
    expect(fError2.selectThisOrThat(fError1).toString(), "false:0:0:false:true:Cannot select file data");

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
    final er = FileDataPrefix.fromFileContent("","");
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
    final p1 = FileDataPrefix.fromFileContent(td1,"braces");
    final p2 = FileDataPrefix.fromFileContent(td2,"abc");
    expect(p1.toString(), "true:9:7:true:false:braces");
    expect(p2.toString(), "false:0:0:false:false:abc");
    expect(p1.isEqual(p2), false);
    expect(p1.selectThisOrThat(p2), p1);
    expect(p2.isEqual(p1), false);
    expect(p2.selectThisOrThat(p1), p1);
  });

  test('Factory fromFileContent not equal or gt error', () async {
    const td1 = "TS:E:9:{}";
    const td2 = "TS:E:10";
    final p1 = FileDataPrefix.fromFileContent(td1, "braces");
    final p2 = FileDataPrefix.fromFileContent(td2, "err");
    expect(p1.toString(), "true:9:7:true:false:braces");
    expect(p2.toString(), "false:0:0:false:true:No data after Timestamp");
    expect(p1.isEqual(p2), false);
    expect(p1.selectThisOrThat(p2), p1);
    expect(p2.isEqual(p1), false);
    expect(p2.selectThisOrThat(p1), p1);
  });

  test('Factory fromFileContent equal', () async {
    const td = "TS:E:9:{}";
    final p1 = FileDataPrefix.fromFileContent("xx","xx");
    final p2 = FileDataPrefix.fromFileContent(td, "braces");
    expect(p1.toString(), "false:0:0:false:false:xx");
    expect(p2.toString(), "true:9:7:true:false:braces");
    expect(p1.isEqual(p2), false);
    expect(p1.selectThisOrThat(p2), p2);
    expect(p2.isEqual(p1), false);
    expect(p2.selectThisOrThat(p1), p2);
  });

  test('Factory fromFileContent equal', () async {
    const td = "TS:E:9:{}";
    final p1 = FileDataPrefix.fromFileContent(td,"braces1");
    final p2 = FileDataPrefix.fromFileContent(td,"braces2");
    expect(p1.toString(), "true:9:7:true:false:braces1");
    expect(p2.toString(), "true:9:7:true:false:braces2");
    expect(p1.isEqual(p2), true);
    expect(p1.selectThisOrThat(p2), p2);
    expect(p2.isEqual(p1), true);
    expect(p2.selectThisOrThat(p1), p1);
  });

  test('Factory fromFileContent OK', () async {
    const td = "TS:E:9:{}";
    final er = FileDataPrefix.fromFileContent(td,"braces");
    expect(er.toString(), "true:9:7:true:false:braces");
    expect(td.substring(er.startPos), "{}");
    expect(er.content, "{}");
  });

  test('Factory fromFileContent OK no : terminal', () async {
    const td = "TS:E:9g";
    final er = FileDataPrefix.fromFileContent(td,"g");
    expect(er.toString(), "true:9:6:true:false:g");
    expect(td.substring(er.startPos), "g");
  });

  test('Factory fromFileContent no data', () async {
    final er = FileDataPrefix.fromFileContent("TS:E:9","err");
    expect(er.toString(), "false:0:0:false:true:No data after Timestamp");
  });

  test('Factory fromFileContent Invalid TS E', () async {
    final er = FileDataPrefix.fromFileContent("TS:E: ","err");
    expect(er.toString(), "false:0:0:false:true:Invalid Timestamp");
  });

  test('Factory fromFileContent Invalid TS C', () async {
    final er = FileDataPrefix.fromFileContent("TS:C: ","err");
    expect(er.toString(), "false:0:0:false:true:Invalid Timestamp");
  });

  test('Factory fromFileContent No TS data C', () async {
    final er = FileDataPrefix.fromFileContent("TS:C:","err");
    expect(er.toString(), "false:0:0:false:true:No Timestamp data");
  });

  test('Factory fromFileContent No TS data E', () async {
    final er = FileDataPrefix.fromFileContent("TS:E:","err");
    expect(er.toString(), "false:0:0:false:true:No Timestamp data");
  });

  test('Factory fromFileContent part prefix', () async {
    final er = FileDataPrefix.fromFileContent("TS","TS");
    expect(er.toString(), "false:0:0:false:false:TS");
  });

  test('Factory fromFileContent noPrefix', () async {
    final er = FileDataPrefix.fromFileContent("abc","abc");
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
