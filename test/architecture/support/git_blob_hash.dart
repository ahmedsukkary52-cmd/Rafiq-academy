import 'dart:convert';
import 'dart:typed_data';

/// Git blob id of [bytes] after CRLF -> LF, matching what `core.autocrlf`
/// stores, so the id is the same on CRLF (Windows) and LF (CI) checkouts.
String gitBlobId(List<int> bytes) {
  final lf = <int>[];
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] == 0x0D && i + 1 < bytes.length && bytes[i + 1] == 0x0A) {
      continue;
    }
    lf.add(bytes[i]);
  }
  return sha1Hex([...ascii.encode('blob ${lf.length}\x00'), ...lf]);
}

/// SHA-1 (FIPS 180-4) as lowercase hex.
String sha1Hex(List<int> message) {
  final length = message.length;
  final padded = (length + 9 + 63) ~/ 64 * 64;
  final data = Uint8List(padded)..setAll(0, message);
  data[length] = 0x80;
  final bits = ByteData.view(data.buffer);
  bits.setUint32(padded - 8, (length * 8) ~/ 0x100000000);
  bits.setUint32(padded - 4, (length * 8) & 0xFFFFFFFF);

  var h0 = 0x67452301;
  var h1 = 0xEFCDAB89;
  var h2 = 0x98BADCFE;
  var h3 = 0x10325476;
  var h4 = 0xC3D2E1F0;
  final w = Uint32List(80);
  int rotl(int x, int n) => ((x << n) | (x >> (32 - n))) & 0xFFFFFFFF;

  for (var chunk = 0; chunk < padded; chunk += 64) {
    for (var t = 0; t < 16; t++) {
      w[t] = bits.getUint32(chunk + t * 4);
    }
    for (var t = 16; t < 80; t++) {
      w[t] = rotl(w[t - 3] ^ w[t - 8] ^ w[t - 14] ^ w[t - 16], 1);
    }
    var a = h0, b = h1, c = h2, d = h3, e = h4;
    for (var t = 0; t < 80; t++) {
      final int f;
      final int k;
      if (t < 20) {
        f = (b & c) | (~b & 0xFFFFFFFF & d);
        k = 0x5A827999;
      } else if (t < 40) {
        f = b ^ c ^ d;
        k = 0x6ED9EBA1;
      } else if (t < 60) {
        f = (b & c) | (b & d) | (c & d);
        k = 0x8F1BBCDC;
      } else {
        f = b ^ c ^ d;
        k = 0xCA62C1D6;
      }
      final temp = (rotl(a, 5) + f + e + k + w[t]) & 0xFFFFFFFF;
      e = d;
      d = c;
      c = rotl(b, 30);
      b = a;
      a = temp;
    }
    h0 = (h0 + a) & 0xFFFFFFFF;
    h1 = (h1 + b) & 0xFFFFFFFF;
    h2 = (h2 + c) & 0xFFFFFFFF;
    h3 = (h3 + d) & 0xFFFFFFFF;
    h4 = (h4 + e) & 0xFFFFFFFF;
  }
  return [
    h0,
    h1,
    h2,
    h3,
    h4,
  ].map((h) => h.toRadixString(16).padLeft(8, '0')).join();
}
