import 'dart:math' as math;

// ==== CONFIGURATION ====
const double centerLat = 18.73149;
const double centerLon = 73.42620;
const double areaKm = 23.328;
const int cellSizeM = 3;
const int totalCodeLen = 5;

// ==== DERIVED VALUES ====
final int gridCellsPerSide = (areaKm * 1000 / cellSizeM).round();
const double halfSideM = areaKm * 1000 / 2;

const double metersPerDegLat = 111320;
final double metersPerDegLon =
    111320 * math.cos(centerLat * math.pi / 180);

final double topLat = centerLat + (halfSideM / metersPerDegLat);
final double leftLon = centerLon - (halfSideM / metersPerDegLon);

// ==== BASE36 ====
const String _alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

String _base36Encode(int number, int length) {
  final chars = <String>[];
  var n = number;
  while (n > 0) {
    final r = n % 36;
    n = n ~/ 36;
    chars.add(_alphabet[r]);
  }
  while (chars.length < length) {
    chars.add('0');
  }
  return chars.reversed.join();
}

int _base36Decode(String s) {
  var value = 0;
  for (var i = 0; i < s.length; i++) {
    value = value * 36 + _alphabet.indexOf(s[i].toUpperCase());
  }
  return value;
}

// ==== MORTON ====
int _interleaveBits(int x, int y) {
  final bits = math.max(x.bitLength, y.bitLength);
  var result = 0;
  for (var i = 0; i < bits; i++) {
    result |= ((y >> i) & 1) << (2 * i);
    result |= ((x >> i) & 1) << (2 * i + 1);
  }
  return result;
}

({int x, int y}) _deinterleaveBits(int z) {
  var x = 0;
  var y = 0;
  var i = 0;
  var v = z;
  while (v > 0) {
    y |= (v & 1) << i;
    v >>= 1;
    x |= (v & 1) << i;
    v >>= 1;
    i++;
  }
  return (x: x, y: y);
}

// ==== GEO MAPPING ====
({int x, int y}) _latLonToXY(double lat, double lon) {
  final distXM = (lon - leftLon) * metersPerDegLon;
  final distYM = (topLat - lat) * metersPerDegLat;

  final x = distXM ~/ cellSizeM;
  final y = distYM ~/ cellSizeM;

  return (x: x, y: y);
}

/// Simple lat/lon result.
class LatLon {
  final double lat;
  final double lon;
  const LatLon(this.lat, this.lon);

  @override
  String toString() => 'LatLon($lat, $lon)';
}

LatLon _xyToLatLon(int x, int y) {
  final distXM = x * cellSizeM + cellSizeM / 2;
  final distYM = y * cellSizeM + cellSizeM / 2;

  final lon = leftLon + (distXM / metersPerDegLon);
  final lat = topLat - (distYM / metersPerDegLat);

  return LatLon(lat, lon);
}

// ==== PUBLIC API ====

/// Converts a latitude/longitude to a 5-character base-36 code.
String latlonToCode(double lat, double lon) {
  final xy = _latLonToXY(lat, lon);
  final mortonId = _interleaveBits(xy.x, xy.y);
  return _base36Encode(mortonId, totalCodeLen);
}

/// Converts a 5-character base-36 code back to a [LatLon].
LatLon codeToLatlon(String code) {
  final mortonId = _base36Decode(code);
  final xy = _deinterleaveBits(mortonId);
  return _xyToLatLon(xy.x, xy.y);
}
