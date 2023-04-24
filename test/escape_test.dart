import 'package:data_repo/detail_widget.dart';
import 'package:data_repo/path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test Boolean name yes', () async {
    final d = DataValueDisplayRow("b","true",bool,true,Path.empty(),1);
    expect(d.name, "b");
    expect(d.value, "Yes");
  });

  test('Test Boolean name no', () async {
    final d = DataValueDisplayRow("b","false",bool,true,Path.empty(),1);
    expect(d.name, "b");
    expect(d.value, "No");
  });

}
