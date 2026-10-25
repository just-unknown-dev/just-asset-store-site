// Turns a backend command's --json document into an issue comment.
//
//     dart run tool/result_message.dart result.json

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final file = File(args.single);
  if (!file.existsSync() || file.lengthSync() == 0) {
    stdout.write('The store could not run the check. A maintainer will look.');
    return;
  }
  final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final result = doc['result'];
  final results = result is Map ? result['outcomes'] : result;
  final lines = <String>[
    if (results is List)
      for (final r in results.whereType<Map<String, dynamic>>())
        '${r['ok'] == true ? (r['held'] == true ? '⏸️' : '✅') : '❌'} ${r['message']}',
    if (doc['error'] != null) '❌ ${doc['error']}',
  ];
  stdout.write(lines.isEmpty ? 'Nothing to report.' : lines.join('\n\n'));
}
