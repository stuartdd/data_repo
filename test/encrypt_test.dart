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
    expect(() => EncryptData.encryptAES("Hello World", '12345678901234567890123456789012a'), throwsA(isA<ArgumentError>()));
    // Test key < _minKeyLen
    expect(() => EncryptData.encryptAES("Hello World", '123'), throwsA(isA<ArgumentError>()));
    // Test incorrect key
    expect(() => EncryptData.decryptAES(ed, '1234|c'), throwsA(isA<ArgumentError>()));
  });
}
