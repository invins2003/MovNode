import 'dart:convert';

class RiveClient {
  static const List<String> _c = [
    "4Z7lUo", "gwIVSMD", "PLmz2elE2v", "Z4OFV0", "SZ6RZq6Zc", "zhJEFYxrz8", "FOm7b0", 
    "axHS3q4KDq", "o9zuXQ", "4Aebt", "wgjjWwKKx", "rY4VIxqSN", "kfjbnSo", "2DyrFA1M", 
    "YUixDM9B", "JQvgEj0", "mcuFx6JIek", "eoTKe26gL", "qaI9EVO1rB", "0xl33btZL", 
    "1fszuAU", "a7jnHzst6P", "wQuJkX", "cBNhTJlEOf", "KNcFWhDvgT", "XipDGjST", 
    "PCZJlbHoyt", "2AYnMZkqd", "HIpJh", "KH0C3iztrG", "W81hjts92", "rJhAT", 
    "NON7LKoMQ", "NMdY3nsKzI", "t4En5v", "Qq5cOQ9H", "Y9nwrp", "VX5FYVfsf", 
    "cE5SJG", "x1vj1", "HegbLe", "zJ3nmt4OA", "gt7rxW57dq", "clIE9b", "jyJ9g", 
    "B5jXjMCSx", "cOzZBZTV", "FTXGy", "Dfh1q1", "ny9jqZ2POI", "X2NnMn", "MBtoyD", 
    "qz4Ilys7wB", "68lbOMye", "3YUJnmxp", "1fv5Imona", "PlfvvXD7mA", "ZarKfHCaPR", 
    "owORnX", "dQP1YU", "dVdkx", "qgiK0E", "cx9wQ", "5F9bGa", "7UjkKrp", "Yvhrj", 
    "wYXez5Dg3", "pG4GMU", "MwMAu", "rFRD5wlM"
  ];

  static String generateSecretKey(String id) {
    try {
      String t;
      int n;
      String r = id.toString();
      
      int numVal = int.tryParse(id) ?? -1;
      if (numVal == -1) {
        int sum = 0;
        for (int i = 0; i < r.length; i++) {
          sum += r.codeUnitAt(i);
        }
        t = _c[sum % _c.length];
        n = ((sum % r.length) / 2).floor();
      } else {
        t = _c[numVal % _c.length];
        n = ((numVal % r.length) / 2).floor();
      }

      String iStr = r.substring(0, n) + t + r.substring(n);

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

      String o = outerHash(innerHash(iStr));
      return base64Encode(utf8.encode(o));
    } catch (e) {
      return "topSecret";
    }
  }
}

void main() {
  print(RiveClient.generateSecretKey('603'));
}
