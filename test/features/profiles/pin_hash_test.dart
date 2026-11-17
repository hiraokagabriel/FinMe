import 'dart:convert';

import 'package:finme/features/profiles/domain/pin_hash.dart';
import 'package:finme/features/profiles/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sha256Hex (vetores NIST)', () {
    test('vazio', () {
      expect(
        sha256Hex(const []),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });
    test('abc', () {
      expect(
        sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });
    test('448 bits (dois blocos)', () {
      expect(
        sha256Hex(
          utf8.encode(
            'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
          ),
        ),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
    });
  });

  test('isValidPin aceita 4 a 8 dígitos', () {
    expect(isValidPin('1234'), isTrue);
    expect(isValidPin('12345678'), isTrue);
    expect(isValidPin('123'), isFalse);
    expect(isValidPin('123456789'), isFalse);
    expect(isValidPin('12a4'), isFalse);
  });

  group('Profile', () {
    final base = Profile(
      id: 'x',
      name: 'Casa',
      createdAt: DateTime(2026, 11, 17),
    );

    test('PIN: certo abre, errado não; sem PIN qualquer um abre', () {
      final locked = base.withPin('2468');
      expect(locked.hasPin, isTrue);
      expect(locked.verifyPin('2468'), isTrue);
      expect(locked.verifyPin('1357'), isFalse);
      expect(base.verifyPin('0000'), isTrue);
      expect(locked.withPin(null).hasPin, isFalse);
    });

    test('mesmo PIN com sal diferente gera hash diferente', () {
      expect(base.withPin('2468').pinHash, isNot(base.withPin('2468').pinHash));
    });

    test('ida e volta pelo map', () {
      final locked = base.withPin('2468');
      final back = Profile.fromMap(locked.toMap());
      expect(back.id, 'x');
      expect(back.name, 'Casa');
      expect(back.createdAt, DateTime(2026, 11, 17));
      expect(back.verifyPin('2468'), isTrue);
      expect(Profile.fromMap(base.toMap()).hasPin, isFalse);
    });
  });
}
