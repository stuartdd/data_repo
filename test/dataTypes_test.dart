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

import 'package:flutter_test/flutter_test.dart';
import 'package:data_repo/data_types.dart';

void main() {
  test('Test Type Validation', () async {
    expect(optionTypeDataInt.validateType(1),"");
    expect(optionTypeDataInt.validateType(1.0),"Is not Integer");
    expect(optionTypeDataInt.validateType(true),"Is not Integer");
    expect(optionTypeDataInt.validateType(false),"Is not Integer");
    expect(optionTypeDataInt.validateType(""),"Is not Integer");

    expect(optionTypeDataDouble.validateType(1),"");
    expect(optionTypeDataDouble.validateType(1.0),"");
    expect(optionTypeDataDouble.validateType(true),"Is not Decimal");
    expect(optionTypeDataDouble.validateType(false),"Is not Decimal");
    expect(optionTypeDataDouble.validateType(""),"Is not Decimal");

    expect(optionTypeDataBool.validateType(1),"Is not Boolean");
    expect(optionTypeDataBool.validateType(1.0),"Is not Boolean");
    expect(optionTypeDataBool.validateType(true),"");
    expect(optionTypeDataBool.validateType(false),"");
    expect(optionTypeDataBool.validateType(""),"Is not Boolean");

    expect(optionTypeDataString.validateType(1),"Is not Text");
    expect(optionTypeDataString.validateType(1.0),"Is not Text");
    expect(optionTypeDataString.validateType(true),"Is not Text");
    expect(optionTypeDataString.validateType(false),"Is not Text");
    expect(optionTypeDataString.validateType(""),"");

    expect(optionTypeDataLink.validateType(1),"Is not Link");
    expect(optionTypeDataLink.validateType(1.0),"Is not Link");
    expect(optionTypeDataLink.validateType(true),"Is not Link");
    expect(optionTypeDataLink.validateType(false),"Is not Link");
    expect(optionTypeDataLink.validateType(""),"");

    expect(optionTypeDataPositional.validateType(1),"Is not Text");
    expect(optionTypeDataPositional.validateType(1.0),"Is not Text");
    expect(optionTypeDataPositional.validateType(true),"Is not Text");
    expect(optionTypeDataPositional.validateType(false),"Is not Text");
    expect(optionTypeDataPositional.validateType(""),"");

    expect(optionTypeDataMarkDown.validateType(1),"Is not Mark Down");
    expect(optionTypeDataMarkDown.validateType(1.0),"Is not Mark Down");
    expect(optionTypeDataMarkDown.validateType(true),"Is not Mark Down");
    expect(optionTypeDataMarkDown.validateType(false),"Is not Mark Down");
    expect(optionTypeDataMarkDown.validateType(""),"");

    expect(optionTypeDataReference.validateType(1),"Is not Reference");
    expect(optionTypeDataReference.validateType(1.0),"Is not Reference");
    expect(optionTypeDataReference.validateType(true),"Is not Reference");
    expect(optionTypeDataReference.validateType(false),"Is not Reference");
    expect(optionTypeDataReference.validateType(""),"");

    expect(optionTypeDataBoolYes.validateType(true),"");
    expect(optionTypeDataBoolYes.validateType(false),"Is Boolean but not Yes");
    expect(optionTypeDataBoolNo.validateType(false),"");
    expect(optionTypeDataBoolNo.validateType(true),"Is Boolean but not No");

    expect(optionTypeDataGroup.validateType(1),"Is not Group");
    expect(optionTypeDataGroup.validateType(1.0),"Is not Group");
    expect(optionTypeDataGroup.validateType(true),"Is not Group");
    expect(optionTypeDataGroup.validateType(false),"Is not Group");
    expect(optionTypeDataGroup.validateType({"ABC":""}),"");

    expect(optionTypeDataValue.validateType(1),"Is not Value");
    expect(optionTypeDataValue.validateType(1.0),"Is not Value");
    expect(optionTypeDataValue.validateType(true),"Is not Value");
    expect(optionTypeDataValue.validateType(false),"Is not Value");
    expect(optionTypeDataValue.validateType(""),"");

    expect(optionsDataTypeEmpty.validateType(""),"Is Empty type");
    expect(optionTypeDataNotFound.validateType(""),"Is Error type");

  });
}
