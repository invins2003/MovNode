void main() {
  int charCode = 100;
  int t = 0x8000;
  int JS_math = (charCode + (t << 6) + (t << 16) - t) & 0xFFFFFFFF;
  print('Dart math: $JS_math');
}
