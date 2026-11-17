import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:finme/core/services/recovery_journal.dart';

void main() {
  group('FileRecoveryJournal', () {
    late Directory dir;
    late File file;
    late FileRecoveryJournal journal;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('finme_journal_');
      file = File('${dir.path}/finme_import_journal.json');
      journal = FileRecoveryJournal(file);
    });

    tearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('read sem arquivo → null; write/read/clear', () async {
      expect(await journal.read(), isNull);

      await journal.write('a');
      expect(await journal.read(), 'a');

      await journal.write('b');
      expect(await journal.read(), 'b');
      expect(File('${file.path}.tmp').existsSync(), isFalse);

      await journal.clear();
      expect(await journal.read(), isNull);
    });

    test('clear sem arquivo não lança', () async {
      await expectLater(journal.clear(), completes);
    });
  });

  group('MemoryRecoveryJournal', () {
    test('failWrites lança e mantém o valor anterior', () async {
      final journal = MemoryRecoveryJournal();
      await journal.write('antigo');

      journal.failWrites = true;
      await expectLater(journal.write('novo'), throwsA(isA<StateError>()));
      expect(await journal.read(), 'antigo');
    });
  });
}
