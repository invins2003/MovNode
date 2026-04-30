void main() {
  String innerHash(String e) {
    int t = 0;
    for (int idx = 0; idx < e.length; idx++) {
      int charCode = e.codeUnitAt(idx);
      t = (charCode + (t << 6) + (t << 16) - t) & 0xFFFFFFFF;
      int innerI = ((t << (idx % 5)) | (t >>> (32 - (idx % 5)))) & 0xFFFFFFFF;
      t = (t ^ (innerI ^ (((charCode << (idx % 7)) | (charCode >>> (8 - (idx % 7)))) & 0xFFFFFFFF))) & 0xFFFFFFFF;
      t = (t + ((t >>> 11) ^ (t << 3))) & 0xFFFFFFFF;
    }
    t ^= t >>> 15;
    t = (((t & 65535) * 49842) + ((((t >>> 16) * 49842) & 65535) << 16)) & 0xFFFFFFFF;
    t ^= t >>> 13;
    t = (((t & 65535) * 40503) + ((((t >>> 16) * 40503) & 65535) << 16)) & 0xFFFFFFFF;
    t ^= t >>> 16;
    return t.toRadixString(16).padLeft(8, '0');
  }

  String outerHash(String e) {
    int n = (3735928559 ^ e.length) & 0xFFFFFFFF;
    for (int idx = 0; idx < e.length; idx++) {
      int charCode = e.codeUnitAt(idx);
      charCode ^= ((131 * idx + 89) ^ (charCode << (idx % 5))) & 255;
      n = (((n << 7) | (n >>> 25)) & 0xFFFFFFFF) ^ charCode;
      int iVal = ((n & 65535) * 60205) & 0xFFFFFFFF;
      int oVal = (((n >>> 16) * 60205) << 16) & 0xFFFFFFFF;
      n = (iVal + oVal) & 0xFFFFFFFF;
      n ^= n >>> 11;
    }
    n ^= n >>> 15;
    n = ((((n & 65535) * 49842) + (((n >>> 16) * 49842) << 16)) & 0xFFFFFFFF) & 0xFFFFFFFF;
    n ^= n >>> 13;
    n = ((((n & 65535) * 40503) + (((n >>> 16) * 40503) << 16)) & 0xFFFFFFFF) & 0xFFFFFFFF;
    n ^= n >>> 16;
    n = ((((n & 65535) * 10196) + (((n >>> 16) * 10196) << 16)) & 0xFFFFFFFF) & 0xFFFFFFFF;
    n ^= n >>> 15;
    return n.toRadixString(16).padLeft(8, '0');
  }
  
  String input = "67QAebt3"; // This is the value of iStr for 673! Wait, let's verify iStr.
  // wait, for 673, numVal = 673.
  // c[673 % 73] = c[16] = "mcuFx6JIek"
  // n = Math.floor((673 % 3) / 2) = Math.floor(1 / 2) = 0
  // iStr = r.slice(0, 0) + "mcuFx6JIek" + r.slice(0) = "mcuFx6JIek673"
  print('Dart innerHash: ' + innerHash('mcuFx6JIek673'));
  print('Dart outerHash: ' + outerHash(innerHash('mcuFx6JIek673')));
}
