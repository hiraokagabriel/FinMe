import 'pin_hash.dart';

/// Sentinela de `copyWith`: parâmetro omitido mantém o valor; `null` explícito limpa.
const Object _keep = Object();

/// Perfil "Principal": usa os boxes `fm_*` de antes dos perfis (SPEC §10.3).
const defaultProfileId = 'default';

/// Perfil com dados isolados e PIN opcional (SPEC §10.1).
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.createdAt,
    this.pinSalt,
    this.pinHash,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
    id: map['id'] as String,
    name: map['name'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
    pinSalt: map['pinSalt'] as String?,
    pinHash: map['pinHash'] as String?,
  );

  final String id;
  final String name;
  final DateTime createdAt;
  final String? pinSalt;
  final String? pinHash;

  bool get hasPin => pinHash != null;

  /// Sem PIN, qualquer entrada abre.
  bool verifyPin(String pin) =>
      !hasPin || hashPin(pin, pinSalt ?? '') == pinHash;

  Profile copyWith({
    String? name,
    Object? pinSalt = _keep,
    Object? pinHash = _keep,
  }) => Profile(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    pinSalt: identical(pinSalt, _keep) ? this.pinSalt : pinSalt as String?,
    pinHash: identical(pinHash, _keep) ? this.pinHash : pinHash as String?,
  );

  /// `null` remove o PIN.
  Profile withPin(String? pin) {
    if (pin == null) {
      return copyWith(pinSalt: null, pinHash: null);
    }
    final salt = newPinSalt();
    return copyWith(pinSalt: salt, pinHash: hashPin(pin, salt));
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    if (pinSalt != null) 'pinSalt': pinSalt,
    if (pinHash != null) 'pinHash': pinHash,
  };
}
