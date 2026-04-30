void main() {
  int toSigned32(int val) {
    int v = val & 0xFFFFFFFF;
    return v > 0x7FFFFFFF ? v - 0x100000000 : v;
  }
  
  int val = 0xA014BF83; // From YTExNGJmODM= -> 0xa014bf83, which has MSB=1
  print(val.toRadixString(16)); // a014bf83
  print(toSigned32(val).toRadixString(16)); // -5eeb407d
}
