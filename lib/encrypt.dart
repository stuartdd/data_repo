import 'package:encrypt/encrypt.dart' as enc;


const int _ivLen = 16;
const int _minKeyLen = 5;

class EncryptData {
  static final List<int> _mangle1 = [56, 87, 36, 51, 90, 94, 77, 58, 40, 38, 70, 57, 79, 64, 61, 50, 46, 63, 35, 79, 81, 61, 70, 53, 33, 67, 87, 73, 91, 66, 45, 89];

  static enc.Encrypted encryptAES(String plainText, String myKey) {
    final key = enc.Key.fromUtf8(_ensureLen(myKey));
    final iv = enc.IV.fromLength(_ivLen);
    final encryptor = enc.Encrypter(enc.AES(key));
    return encryptor.encrypt(plainText, iv: iv);
  }

  static String decrypt(String encrypted, String myKey) {
    final encr = enc.Encrypted.from64(encrypted);
    return decryptAES(encr,myKey);
  }

  static String decryptAES(enc.Encrypted encrypted, String myKey) {
    final key = enc.Key.fromUtf8(_ensureLen(myKey));
    final iv = enc.IV.fromLength(_ivLen);
    final encryptor = enc.Encrypter(enc.AES(key));
    return encryptor.decrypt(encrypted, iv: iv);
  }

  static String _ensureLen(String s) {
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
      b[i] = b[i] ^ _mangle1[i];
    }
    return String.fromCharCodes(b);
  }
}
