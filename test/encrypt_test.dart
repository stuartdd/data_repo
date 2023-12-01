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
import 'package:data_repo/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test Encrypt/Decrypt', () async {
    var ed = EncryptData.encryptAES("Hello World", '1234567890');
    expect(ed.base64, "TyWLg1hI/LTM9REp3sgTdg==");
    String pl = EncryptData.decryptAES(ed, '1234567890');
    expect(pl, "Hello World");
    ed = EncryptData.encryptAES("Hello World", '1234|');
    expect(ed.base64, "P32GtNQe+pT43k+fnOZrWQ==");
    pl = EncryptData.decryptAES(ed, '1234|');
    expect(pl, "Hello World");

    ed = EncryptData.encryptAES("This is it", '1234|');
    var d = ed.base64;
    expect(d, "I3CDq5tX3tvjxi2cn+VoWg==");
    var s = EncryptData.decrypt(d, '1234|');
    expect(s, "This is it");

    // Test key > 32
    expect(
        () => EncryptData.encryptAES(
            "Hello World", '12345678901234567890123456789012a'),
        throwsA(isA<ArgumentError>()));
    // Test key < _minKeyLen
    expect(() => EncryptData.encryptAES("Hello World", '123'),
        throwsA(isA<ArgumentError>()));
    // Test incorrect key
    expect(() => EncryptData.decryptAES(ed, '1234|c'),
        throwsA(isA<ArgumentError>()));
  });
}
