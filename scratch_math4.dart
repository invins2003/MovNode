void main() {
  String _toHex32(int val) {
    int v = val & 0xFFFFFFFF;
    if (v > 0x7FFFFFFF) v = v - 0x100000000;
    return v.toRadixString(16).padLeft(8, '0');
  }

  String innerHash(String e) {
    int t = 0;
    for (int idx = 0; idx < e.length; idx++) {
      int charCode = e.codeUnitAt(idx);
      int t_shl_6 = (t << 6) & 0xFFFFFFFF;
      if (t_shl_6 > 0x7FFFFFFF) t_shl_6 -= 0x100000000;
      int t_shl_16 = (t << 16) & 0xFFFFFFFF;
      if (t_shl_16 > 0x7FFFFFFF) t_shl_16 -= 0x100000000;
      t = (charCode + t_shl_6 + t_shl_16 - t) & 0xFFFFFFFF;
      int innerI = ((t << (idx % 5)) | (t >>> (32 - (idx % 5)))) & 0xFFFFFFFF;
      t = (t ^ (innerI ^ (((charCode << (idx % 7)) | (charCode >>> (8 - (idx % 7)))) & 0xFFFFFFFF))) & 0xFFFFFFFF;
      int t_shr_11 = (t >>> 11) & 0xFFFFFFFF;
      int t_shl_3 = (t << 3) & 0xFFFFFFFF;
      if (t_shl_3 > 0x7FFFFFFF) t_shl_3 -= 0x100000000;
      int xor_val = (t_shr_11 ^ t_shl_3) & 0xFFFFFFFF;
      if (xor_val > 0x7FFFFFFF) xor_val -= 0x100000000;
      t = (t + xor_val) & 0xFFFFFFFF;
    }
    t ^= t >>> 15;
    t = (((t & 65535) * 49842) + ((((t >>> 16) * 49842) & 65535) << 16)) & 0xFFFFFFFF;
    t ^= t >>> 13;
    t = (((t & 65535) * 40503) + ((((t >>> 16) * 40503) & 65535) << 16)) & 0xFFFFFFFF;
    t ^= t >>> 16;
    return _toHex32(t);
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
    return _toHex32(n);
  }
  
  print('Dart innerHash: ' + innerHash('mcuFx6JIek673'));
  print('Dart outerHash: ' + outerHash(innerHash('mcuFx6JIek673')));
}
