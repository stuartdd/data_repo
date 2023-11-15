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
import 'package:data_repo/data_types.dart';
import 'package:data_repo/detail_widget.dart';
import 'package:data_repo/path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test Boolean name yes', () async {
    final d = DataValueDisplayRow("b", "true", optionTypeDataBoolYes, true, Path.empty(), 1);
    expect(d.name, "b");
    expect(d.value, "Yes");
  });

  test('Test Boolean name no', () async {
    final d = DataValueDisplayRow("b", "false", optionTypeDataBoolNo, true, Path.empty(), 1);
    expect(d.name, "b");
    expect(d.value, "No");
  });
}
