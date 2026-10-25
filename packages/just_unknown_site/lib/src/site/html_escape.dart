/// Escapes text for safe inclusion in HTML text nodes and attributes.
String esc(Object? s) => '$s'
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

final String _backslash = String.fromCharCode(0x5C);

/// JSON embedded in `<script>` must never contain `</` (early close). JSON
/// unicode escapes (backslash-u003c / u003e) keep the payload valid JSON.
String escJsonForScript(String json) => json
    .replaceAll('<', '${_backslash}u003c')
    .replaceAll('>', '${_backslash}u003e');
