/// What the Publish form accepts, in pure Dart. `firestore.rules` checks
/// the same shapes, and the backend checks them again.
abstract final class SubmissionRules {
  /// The longest note the form takes.
  static const int noteMax = 500;

  /// Categories only the store's own packages use.
  static const Set<String> reservedCategories = {'core'};

  static final _repo = RegExp(
    r'^https://github\.com/([A-Za-z0-9](?:[A-Za-z0-9-]{0,38}))/([A-Za-z0-9._-]{1,100})$',
  );

  /// [input] as the repository address the store stores
  /// (`https://github.com/owner/name`), or null when it isn't a GitHub
  /// repository's address.
  static String? normalizeRepo(String input) {
    var s = input.trim();
    if (s.startsWith('http://')) s = 'https://${s.substring(7)}';
    if (s.startsWith('github.com/')) s = 'https://$s';
    s = s.replaceFirst('https://www.github.com/', 'https://github.com/');
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.git')) s = s.substring(0, s.length - 4);
    final m = _repo.firstMatch(s);
    if (m == null) return null;
    final name = m.group(2)!;
    if (name == '.' || name == '..') return null;
    return s;
  }

  /// Why [input] isn't a repository address, or null when it is one.
  static String? repoProblem(String input) {
    if (input.trim().isEmpty) return 'Paste your repository’s address.';
    if (normalizeRepo(input) == null) {
      return 'Use the repository’s GitHub address: '
          'https://github.com/owner/name';
    }
    return null;
  }
}
