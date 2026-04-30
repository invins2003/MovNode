void main() {
  int t = 0x801F8064;
  int JS_math2 = (t + ((t >>> 11) ^ (t << 3))) & 0xFFFFFFFF;
  print('Dart math2: $JS_math2');
}
