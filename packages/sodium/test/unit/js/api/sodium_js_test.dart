import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:sodium/src/js/api/crypto_js.dart';
import 'package:sodium/src/js/api/randombytes_js.dart';
import 'package:sodium/src/js/api/sodium_js.dart';
import 'package:sodium/src/js/bindings/sodium.js.dart';
import 'package:test/test.dart';

class MockLibSodiumJS extends Mock implements LibSodiumJS {}

void main() {
  final mockSodium = MockLibSodiumJS();

  late SodiumJS sut;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    reset(mockSodium);

    sut = SodiumJS(mockSodium);
  });

  test('version returns correct library version', () {
    const vStr = 'version';
    when(() => mockSodium.SODIUM_LIBRARY_VERSION_MAJOR).thenReturn(1);
    when(() => mockSodium.SODIUM_LIBRARY_VERSION_MINOR).thenReturn(2);
    when(() => mockSodium.sodium_version_string()).thenReturn(vStr);

    final version = sut.version;

    expect(version.major, 1);
    expect(version.minor, 2);
    expect(version.toString(), 'version');

    verify(() => mockSodium.SODIUM_LIBRARY_VERSION_MAJOR);
    verify(() => mockSodium.SODIUM_LIBRARY_VERSION_MINOR);
    verify(() => mockSodium.sodium_version_string());
  });

  test('pad', () {
    final inBuf = Uint8List.fromList(const [1, 2, 3]);
    final outBuf = Uint8List.fromList(const [1, 2, 3, 4, 5]);
    const blocksize = 10;

    when(() => mockSodium.pad(any(), any())).thenReturn(outBuf);

    final res = sut.pad(inBuf, blocksize);

    expect(res, outBuf);
    verify(() => mockSodium.pad(inBuf, blocksize));
  });

  test('unpad', () {
    final inBuf = Uint8List.fromList(const [1, 2, 3, 4, 5]);
    final outBuf = Uint8List.fromList(const [1, 2, 3]);
    const blocksize = 10;

    when(() => mockSodium.unpad(any(), any())).thenReturn(outBuf);

    final res = sut.unpad(inBuf, blocksize);

    expect(res, outBuf);
    verify(() => mockSodium.unpad(inBuf, blocksize));
  });

  test('secureAlloc creates SecureKey instance', () {
    const length = 10;
    final res = sut.secureAlloc(length);

    expect(res.length, length);
  });

  test('secureRandom creates random SecureKey instance', () {
    const length = 10;
    when(() => mockSodium.randombytes_buf(any())).thenReturn(Uint8List(length));

    final res = sut.secureRandom(length);

    expect(res.length, length);

    verify(() => mockSodium.randombytes_buf(length));
  });

  test('randombytes returns RandombytesJS instance', () {
    expect(
      sut.randombytes,
      isA<RandombytesJS>().having(
        (p) => p.sodium,
        'sodium',
        mockSodium,
      ),
    );
  });

  test('crypto returns CryptoJS instance', () {
    expect(
      sut.crypto,
      isA<CryptoJS>().having(
        (p) => p.sodium,
        'sodium',
        mockSodium,
      ),
    );
  });
}
