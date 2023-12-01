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
import 'package:encrypt/encrypt.dart' as enc;

const int _minKeyLen = 5;
const _randStr16 = "O84+5PO7bV6nwvid";
const _mangle32 = [56, 87, 36, 51, 90, 94, 77, 58, 40, 38, 70, 57, 79, 64, 61, 50, 46, 63, 35, 79, 81, 61, 70, 53, 33, 67, 87, 73, 91, 66, 45, 89];

class EncryptData {

  static enc.Encrypted encryptAES(String plainText, String myKey) {
    final key = enc.Key.fromUtf8(_mangle(myKey));
    // final iv = enc.IV.fromUtf8(_randStr16);
    final iv = enc.IV.allZerosOfLength(16);
    final encryptor = enc.Encrypter(enc.AES(key));
    return encryptor.encrypt(plainText, iv: iv);
  }

  static String decrypt(String encrypted, String myKey) {
    return decryptAES(enc.Encrypted.from64(encrypted),myKey);
  }

  static String decryptAES(enc.Encrypted encrypted, String myKey) {
    final key = enc.Key.fromUtf8(_mangle(myKey));
    // final iv = enc.IV.fromUtf8(_randStr16);
    final iv = enc.IV.allZerosOfLength(16);
    final encryptor = enc.Encrypter(enc.AES(key));
    return encryptor.decrypt(encrypted, iv: iv);
  }

  static String _mangle(String s) {
    String myKey = s.trim();
    if (myKey.length < _minKeyLen || myKey.length > 32) {
      throw ArgumentError("Encryption/Decryption Key should be between $_minKeyLen and 32 characters", "key");
    }
    List<int> k = myKey.codeUnits;
    List<int> b = List.generate(32, (index) => 0);
    var kl = k.length;
    for (var i = 0; i < b.length; i++) {
      b[i] = k[i % kl];
    }
    for (var i = 0; i < k.length; i++) {
      b[i] = b[i] ^ _mangle32[i];
    }
    return String.fromCharCodes(b);
  }
}
