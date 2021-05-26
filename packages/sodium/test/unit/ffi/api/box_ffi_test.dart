import 'dart:ffi';
import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:sodium/src/api/detached_cipher_result.dart';
import 'package:sodium/src/api/secure_key.dart';
import 'package:sodium/src/api/sodium_exception.dart';
import 'package:sodium/src/ffi/api/box_ffi.dart';
import 'package:sodium/src/ffi/bindings/libsodium.ffi.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import '../../../secure_key_fake.dart';
import '../../../test_constants_mapping.dart';
import '../keygen_test_helpers.dart';
import '../pointer_test_helpers.dart';

class MockSodiumFFI extends Mock implements LibSodiumFFI {}

void main() {
  final mockSodium = MockSodiumFFI();

  late BoxFFI sut;

  setUpAll(() {
    registerPointers();
  });

  setUp(() {
    reset(mockSodium);

    mockAllocArray(mockSodium);

    sut = BoxFFI(mockSodium);
  });

  testConstantsMapping([
    Tuple3(
      () => mockSodium.crypto_box_publickeybytes(),
      () => sut.publicKeyBytes,
      'publicKeyBytes',
    ),
    Tuple3(
      () => mockSodium.crypto_box_secretkeybytes(),
      () => sut.secretKeyBytes,
      'secretKeyBytes',
    ),
    Tuple3(
      () => mockSodium.crypto_box_macbytes(),
      () => sut.macBytes,
      'macBytes',
    ),
    Tuple3(
      () => mockSodium.crypto_box_noncebytes(),
      () => sut.nonceBytes,
      'nonceBytes',
    ),
    Tuple3(
      () => mockSodium.crypto_box_seedbytes(),
      () => sut.seedBytes,
      'seedBytes',
    ),
    Tuple3(
      () => mockSodium.crypto_box_sealbytes(),
      () => sut.sealBytes,
      'sealBytes',
    ),
  ]);

  group('methods', () {
    setUp(() {
      when(() => mockSodium.crypto_box_publickeybytes()).thenReturn(5);
      when(() => mockSodium.crypto_box_secretkeybytes()).thenReturn(5);
      when(() => mockSodium.crypto_box_macbytes()).thenReturn(5);
      when(() => mockSodium.crypto_box_noncebytes()).thenReturn(5);
      when(() => mockSodium.crypto_box_seedbytes()).thenReturn(5);
      when(() => mockSodium.crypto_box_sealbytes()).thenReturn(5);
    });

    testKeypair(
      mockSodium: mockSodium,
      runKeypair: () => sut.keyPair(),
      secretKeyBytesNative: mockSodium.crypto_box_secretkeybytes,
      publicKeyBytesNative: mockSodium.crypto_box_publickeybytes,
      keypairNative: mockSodium.crypto_box_keypair,
    );

    testSeedKeypair(
      mockSodium: mockSodium,
      runSeedKeypair: (SecureKey seed) => sut.seedKeyPair(seed),
      seedBytesNative: mockSodium.crypto_box_seedbytes,
      secretKeyBytesNative: mockSodium.crypto_box_secretkeybytes,
      publicKeyBytesNative: mockSodium.crypto_box_publickeybytes,
      seedKeypairNative: mockSodium.crypto_box_seed_keypair,
    );

    group('easy', () {
      test('asserts if nonce is invalid', () {
        expect(
          () => sut.easy(
            message: Uint8List(20),
            nonce: Uint8List(10),
            recipientPublicKey: Uint8List(5),
            senderSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_noncebytes());
      });

      test('asserts if recipientPublicKey is invalid', () {
        expect(
          () => sut.easy(
            message: Uint8List(20),
            nonce: Uint8List(5),
            recipientPublicKey: Uint8List(10),
            senderSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_publickeybytes());
      });

      test('asserts if senderSecretKey is invalid', () {
        expect(
          () => sut.easy(
            message: Uint8List(20),
            nonce: Uint8List(5),
            recipientPublicKey: Uint8List(5),
            senderSecretKey: SecureKeyFake.empty(10),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_secretkeybytes());
      });

      test('calls crypto_box_easy with correct arguments', () {
        when(
          () => mockSodium.crypto_box_easy(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(0);

        final message = List.generate(20, (index) => index * 2);
        final nonce = List.generate(5, (index) => 10 + index);
        final recipientPublicKey = List.generate(5, (index) => 20 + index);
        final senderSecretKey = List.generate(5, (index) => 30 + index);
        final mac = List.filled(5, 0);

        sut.easy(
          message: Uint8List.fromList(message),
          nonce: Uint8List.fromList(nonce),
          recipientPublicKey: Uint8List.fromList(recipientPublicKey),
          senderSecretKey: SecureKeyFake(senderSecretKey),
        );

        verifyInOrder([
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(nonce)),
              ),
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(recipientPublicKey)),
              ),
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(senderSecretKey)),
              ),
          () => mockSodium.crypto_box_easy(
                any(that: hasRawData<Uint8>(mac + message)),
                any(that: hasRawData<Uint8>(message)),
                message.length,
                any(that: hasRawData<Uint8>(nonce)),
                any(that: hasRawData<Uint8>(recipientPublicKey)),
                any(that: hasRawData<Uint8>(senderSecretKey)),
              ),
        ]);
      });

      test('returns encrypted data', () {
        final cipher = List.generate(25, (index) => 100 - index);
        when(
          () => mockSodium.crypto_box_easy(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((i) {
          fillPointer(i.positionalArguments.first as Pointer<Uint8>, cipher);
          return 0;
        });

        final result = sut.easy(
          message: Uint8List(20),
          nonce: Uint8List(5),
          recipientPublicKey: Uint8List(5),
          senderSecretKey: SecureKeyFake.empty(5),
        );

        expect(result, cipher);

        verify(() => mockSodium.sodium_free(any())).called(4);
      });

      test('throws exception on failure', () {
        when(
          () => mockSodium.crypto_box_easy(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(1);

        expect(
          () => sut.easy(
            message: Uint8List(10),
            nonce: Uint8List(5),
            recipientPublicKey: Uint8List(5),
            senderSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<SodiumException>()),
        );

        verify(() => mockSodium.sodium_free(any())).called(4);
      });
    });

    group('openEasy', () {
      test('asserts if cipherText is invalid', () {
        expect(
          () => sut.openEasy(
            cipherText: Uint8List(3),
            nonce: Uint8List(5),
            senderPublicKey: Uint8List(5),
            recipientSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_macbytes());
      });

      test('asserts if nonce is invalid', () {
        expect(
          () => sut.openEasy(
            cipherText: Uint8List(20),
            nonce: Uint8List(10),
            senderPublicKey: Uint8List(5),
            recipientSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_noncebytes());
      });

      test('asserts if senderPublicKey is invalid', () {
        expect(
          () => sut.openEasy(
            cipherText: Uint8List(20),
            nonce: Uint8List(5),
            senderPublicKey: Uint8List(10),
            recipientSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_publickeybytes());
      });

      test('asserts if recipientSecretKey is invalid', () {
        expect(
          () => sut.openEasy(
            cipherText: Uint8List(20),
            nonce: Uint8List(5),
            senderPublicKey: Uint8List(5),
            recipientSecretKey: SecureKeyFake.empty(10),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_secretkeybytes());
      });

      test('calls crypto_box_open_easy with correct arguments', () {
        when(
          () => mockSodium.crypto_box_open_easy(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(0);

        final cipherText = List.generate(20, (index) => index * 2);
        final nonce = List.generate(5, (index) => 10 + index);
        final senderPublicKey = List.generate(5, (index) => 20 + index);
        final recipientSecretKey = List.generate(5, (index) => 30 + index);

        sut.openEasy(
          cipherText: Uint8List.fromList(cipherText),
          nonce: Uint8List.fromList(nonce),
          senderPublicKey: Uint8List.fromList(senderPublicKey),
          recipientSecretKey: SecureKeyFake(recipientSecretKey),
        );

        verifyInOrder([
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(nonce)),
              ),
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(senderPublicKey)),
              ),
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(recipientSecretKey)),
              ),
          () => mockSodium.crypto_box_open_easy(
                any(that: hasRawData<Uint8>(cipherText.sublist(5))),
                any(that: hasRawData<Uint8>(cipherText)),
                cipherText.length,
                any(that: hasRawData<Uint8>(nonce)),
                any(that: hasRawData<Uint8>(senderPublicKey)),
                any(that: hasRawData<Uint8>(recipientSecretKey)),
              ),
        ]);
      });

      test('returns decrypted data', () {
        final message = List.generate(8, (index) => index * 5);
        when(
          () => mockSodium.crypto_box_open_easy(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((i) {
          fillPointer(i.positionalArguments.first as Pointer<Uint8>, message);
          return 0;
        });

        final result = sut.openEasy(
          cipherText: Uint8List(13),
          nonce: Uint8List(5),
          senderPublicKey: Uint8List(5),
          recipientSecretKey: SecureKeyFake.empty(5),
        );

        expect(result, message);

        verify(() => mockSodium.sodium_free(any())).called(4);
      });

      test('throws exception on failure', () {
        when(
          () => mockSodium.crypto_box_open_easy(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(1);

        expect(
          () => sut.openEasy(
            cipherText: Uint8List(10),
            nonce: Uint8List(5),
            senderPublicKey: Uint8List(5),
            recipientSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<SodiumException>()),
        );

        verify(() => mockSodium.sodium_free(any())).called(4);
      });
    });

    group('detached', () {
      test('asserts if nonce is invalid', () {
        expect(
          () => sut.detached(
            message: Uint8List(20),
            nonce: Uint8List(10),
            recipientPublicKey: Uint8List(5),
            senderSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_noncebytes());
      });

      test('asserts if recipientPublicKey is invalid', () {
        expect(
          () => sut.detached(
            message: Uint8List(20),
            nonce: Uint8List(5),
            recipientPublicKey: Uint8List(10),
            senderSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_publickeybytes());
      });

      test('asserts if senderSecretKey is invalid', () {
        expect(
          () => sut.detached(
            message: Uint8List(20),
            nonce: Uint8List(5),
            recipientPublicKey: Uint8List(5),
            senderSecretKey: SecureKeyFake.empty(10),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_secretkeybytes());
      });

      test('calls crypto_box_detached with correct arguments', () {
        when(
          () => mockSodium.crypto_box_detached(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(0);

        final message = List.generate(20, (index) => index * 2);
        final nonce = List.generate(5, (index) => 10 + index);
        final recipientPublicKey = List.generate(5, (index) => 20 + index);
        final senderSecretKey = List.generate(5, (index) => 30 + index);

        sut.detached(
          message: Uint8List.fromList(message),
          nonce: Uint8List.fromList(nonce),
          recipientPublicKey: Uint8List.fromList(recipientPublicKey),
          senderSecretKey: SecureKeyFake(senderSecretKey),
        );

        verifyInOrder([
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(nonce)),
              ),
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(recipientPublicKey)),
              ),
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(senderSecretKey)),
              ),
          () => mockSodium.crypto_box_detached(
                any(that: hasRawData<Uint8>(message)),
                any(that: isNot(nullptr)),
                any(that: hasRawData<Uint8>(message)),
                message.length,
                any(that: hasRawData<Uint8>(nonce)),
                any(that: hasRawData<Uint8>(recipientPublicKey)),
                any(that: hasRawData<Uint8>(senderSecretKey)),
              ),
        ]);
      });

      test('returns encrypted data and mac', () {
        final cipherText = List.generate(10, (index) => index);
        final mac = List.generate(5, (index) => index * 3);
        when(
          () => mockSodium.crypto_box_detached(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((i) {
          fillPointer(i.positionalArguments[0] as Pointer<Uint8>, cipherText);
          fillPointer(i.positionalArguments[1] as Pointer<Uint8>, mac);
          return 0;
        });

        final result = sut.detached(
          message: Uint8List(10),
          nonce: Uint8List(5),
          recipientPublicKey: Uint8List(5),
          senderSecretKey: SecureKeyFake.empty(5),
        );

        expect(
          result,
          DetachedCipherResult(
            cipherText: Uint8List.fromList(cipherText),
            mac: Uint8List.fromList(mac),
          ),
        );

        verify(() => mockSodium.sodium_free(any())).called(5);
      });

      test('throws exception on failure', () {
        when(
          () => mockSodium.crypto_box_detached(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(1);

        expect(
          () => sut.detached(
            message: Uint8List(10),
            nonce: Uint8List(5),
            recipientPublicKey: Uint8List(5),
            senderSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<SodiumException>()),
        );

        verify(() => mockSodium.sodium_free(any())).called(5);
      });
    });

    group('openDetached', () {
      test('asserts if mac is invalid', () {
        expect(
          () => sut.openDetached(
            cipherText: Uint8List(10),
            mac: Uint8List(10),
            nonce: Uint8List(5),
            senderPublicKey: Uint8List(5),
            recipientSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_macbytes());
      });

      test('asserts if nonce is invalid', () {
        expect(
          () => sut.openDetached(
            cipherText: Uint8List(10),
            mac: Uint8List(5),
            nonce: Uint8List(10),
            senderPublicKey: Uint8List(5),
            recipientSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_noncebytes());
      });

      test('asserts if senderPublicKey is invalid', () {
        expect(
          () => sut.openDetached(
            cipherText: Uint8List(10),
            mac: Uint8List(5),
            nonce: Uint8List(5),
            senderPublicKey: Uint8List(10),
            recipientSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_publickeybytes());
      });

      test('asserts if recipientSecretKey is invalid', () {
        expect(
          () => sut.openDetached(
            cipherText: Uint8List(10),
            mac: Uint8List(5),
            nonce: Uint8List(5),
            senderPublicKey: Uint8List(5),
            recipientSecretKey: SecureKeyFake.empty(10),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_secretkeybytes());
      });

      test('calls crypto_secretbox_open_detached with correct arguments', () {
        when(
          () => mockSodium.crypto_box_open_detached(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(0);

        final cipherText = List.generate(15, (index) => index * 2);
        final mac = List.generate(5, (index) => 20 - index);
        final nonce = List.generate(5, (index) => 10 + index);
        final senderPublicKey = List.generate(5, (index) => 20 + index);
        final recipientSecretKey = List.generate(5, (index) => 30 + index);

        sut.openDetached(
          cipherText: Uint8List.fromList(cipherText),
          mac: Uint8List.fromList(mac),
          nonce: Uint8List.fromList(nonce),
          senderPublicKey: Uint8List.fromList(senderPublicKey),
          recipientSecretKey: SecureKeyFake(recipientSecretKey),
        );

        verifyInOrder([
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(mac)),
              ),
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(nonce)),
              ),
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(senderPublicKey)),
              ),
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(recipientSecretKey)),
              ),
          () => mockSodium.crypto_box_open_detached(
                any(that: hasRawData<Uint8>(cipherText)),
                any(that: hasRawData<Uint8>(cipherText)),
                any(that: hasRawData<Uint8>(mac)),
                cipherText.length,
                any(that: hasRawData<Uint8>(nonce)),
                any(that: hasRawData<Uint8>(senderPublicKey)),
                any(that: hasRawData<Uint8>(recipientSecretKey)),
              ),
        ]);
      });

      test('returns decrypted data', () {
        final message = List.generate(25, (index) => index);
        when(
          () => mockSodium.crypto_box_open_detached(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((i) {
          fillPointer(i.positionalArguments.first as Pointer<Uint8>, message);
          return 0;
        });

        final result = sut.openDetached(
          cipherText: Uint8List(25),
          mac: Uint8List(5),
          nonce: Uint8List(5),
          senderPublicKey: Uint8List(5),
          recipientSecretKey: SecureKeyFake.empty(5),
        );

        expect(result, message);

        verify(() => mockSodium.sodium_free(any())).called(5);
      });

      test('throws exception on failure', () {
        when(
          () => mockSodium.crypto_box_open_detached(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(1);

        expect(
          () => sut.openDetached(
            cipherText: Uint8List(10),
            mac: Uint8List(5),
            nonce: Uint8List(5),
            senderPublicKey: Uint8List(5),
            recipientSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<SodiumException>()),
        );

        verify(() => mockSodium.sodium_free(any())).called(5);
      });
    });

    group('seal', () {
      test('asserts if recipientPublicKey is invalid', () {
        expect(
          () => sut.seal(
            message: Uint8List(20),
            recipientPublicKey: Uint8List(10),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_publickeybytes());
      });

      test('calls crypto_box_seal with correct arguments', () {
        when(
          () => mockSodium.crypto_box_seal(
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(0);

        final message = List.generate(20, (index) => index * 2);
        final recipientPublicKey = List.generate(5, (index) => 20 + index);
        final seal = List.filled(5, 0);

        sut.seal(
          message: Uint8List.fromList(message),
          recipientPublicKey: Uint8List.fromList(recipientPublicKey),
        );

        verifyInOrder([
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(recipientPublicKey)),
              ),
          () => mockSodium.crypto_box_seal(
                any(that: hasRawData<Uint8>(seal + message)),
                any(that: hasRawData<Uint8>(message)),
                message.length,
                any(that: hasRawData<Uint8>(recipientPublicKey)),
              ),
        ]);
      });

      test('returns sealed data', () {
        final cipher = List.generate(25, (index) => 100 - index);
        when(
          () => mockSodium.crypto_box_seal(
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((i) {
          fillPointer(i.positionalArguments.first as Pointer<Uint8>, cipher);
          return 0;
        });

        final result = sut.seal(
          message: Uint8List(20),
          recipientPublicKey: Uint8List(5),
        );

        expect(result, cipher);

        verify(() => mockSodium.sodium_free(any())).called(2);
      });

      test('throws exception on failure', () {
        when(
          () => mockSodium.crypto_box_seal(
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(1);

        expect(
          () => sut.seal(
            message: Uint8List(10),
            recipientPublicKey: Uint8List(5),
          ),
          throwsA(isA<SodiumException>()),
        );

        verify(() => mockSodium.sodium_free(any())).called(2);
      });
    });

    group('sealOpen', () {
      test('asserts if cipherText is invalid', () {
        expect(
          () => sut.sealOpen(
            cipherText: Uint8List(3),
            recipientPublicKey: Uint8List(5),
            recipientSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_sealbytes());
      });

      test('asserts if recipientPublicKey is invalid', () {
        expect(
          () => sut.sealOpen(
            cipherText: Uint8List(20),
            recipientPublicKey: Uint8List(10),
            recipientSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_publickeybytes());
      });

      test('asserts if recipientSecretKey is invalid', () {
        expect(
          () => sut.sealOpen(
            cipherText: Uint8List(20),
            recipientPublicKey: Uint8List(5),
            recipientSecretKey: SecureKeyFake.empty(10),
          ),
          throwsA(isA<RangeError>()),
        );

        verify(() => mockSodium.crypto_box_secretkeybytes());
      });

      test('calls crypto_box_seal_open with correct arguments', () {
        when(
          () => mockSodium.crypto_box_seal_open(
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(0);

        final cipherText = List.generate(20, (index) => index * 2);
        final recipientPublicKey = List.generate(5, (index) => 20 + index);
        final recipientSecretKey = List.generate(5, (index) => 30 + index);

        sut.sealOpen(
          cipherText: Uint8List.fromList(cipherText),
          recipientPublicKey: Uint8List.fromList(recipientPublicKey),
          recipientSecretKey: SecureKeyFake(recipientSecretKey),
        );

        verifyInOrder([
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(recipientPublicKey)),
              ),
          () => mockSodium.sodium_mprotect_readonly(
                any(that: hasRawData(recipientSecretKey)),
              ),
          () => mockSodium.crypto_box_seal_open(
                any(that: hasRawData<Uint8>(cipherText.sublist(5))),
                any(that: hasRawData<Uint8>(cipherText)),
                cipherText.length,
                any(that: hasRawData<Uint8>(recipientPublicKey)),
                any(that: hasRawData<Uint8>(recipientSecretKey)),
              ),
        ]);
      });

      test('returns decrypted data', () {
        final message = List.generate(8, (index) => index * 5);
        when(
          () => mockSodium.crypto_box_seal_open(
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((i) {
          fillPointer(i.positionalArguments.first as Pointer<Uint8>, message);
          return 0;
        });

        final result = sut.sealOpen(
          cipherText: Uint8List(13),
          recipientPublicKey: Uint8List(5),
          recipientSecretKey: SecureKeyFake.empty(5),
        );

        expect(result, message);

        verify(() => mockSodium.sodium_free(any())).called(3);
      });

      test('throws exception on failure', () {
        when(
          () => mockSodium.crypto_box_seal_open(
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(1);

        expect(
          () => sut.sealOpen(
            cipherText: Uint8List(13),
            recipientPublicKey: Uint8List(5),
            recipientSecretKey: SecureKeyFake.empty(5),
          ),
          throwsA(isA<SodiumException>()),
        );

        verify(() => mockSodium.sodium_free(any())).called(3);
      });
    });
  });
}
