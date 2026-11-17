import 'dart:io';

/// Retrato JSON do estado anterior a um import de backup, para recuperar após queda.
abstract interface class RecoveryJournal {
  /// null = sem retrato pendente.
  Future<String?> read();

  /// Grava em `<arquivo>.tmp` e renomeia por cima (troca atômica no mesmo volume).
  Future<void> write(String json);

  /// Apaga; arquivo ausente → ok.
  Future<void> clear();
}

/// Em memória (uso: testes). `failWrites` simula falha de disco no `write`.
class MemoryRecoveryJournal implements RecoveryJournal {
  String? _json;
  bool failWrites = false;

  @override
  Future<String?> read() async => _json;

  @override
  Future<void> write(String json) async {
    if (failWrites) {
      throw StateError('Falha simulada ao gravar o retrato');
    }
    _json = json;
  }

  @override
  Future<void> clear() async {
    _json = null;
  }
}

/// Retrato em arquivo (dart:io). Escrita com arquivo temporário + rename.
class FileRecoveryJournal implements RecoveryJournal {
  FileRecoveryJournal(this.file);

  final File file;

  @override
  Future<String?> read() async {
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<void> write(String json) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<void> clear() async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
