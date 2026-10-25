import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// A monospace command with a copy button. [prompt] goes before it.
class CodeCard extends StatefulWidget {
  const CodeCard(this.code, {super.key, this.prompt = r'$ '});

  final String code;
  final String prompt;

  @override
  State<CodeCard> createState() => _CodeCardState();
}

class _CodeCardState extends State<CodeCard> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        JuSpacing.x5,
        JuSpacing.x3,
        JuSpacing.x2,
        JuSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: context.tokens.codeBackground,
        borderRadius: BorderRadius.circular(JuRadii.md),
        border: Border.all(color: context.tokens.border),
      ),
      child: Row(
        children: [
          if (widget.prompt.isNotEmpty)
            Text(
              widget.prompt,
              style: juMonoStyle.copyWith(color: context.colors.primary),
            ),
          Expanded(
            child: SelectableText(
              widget.code,
              style: juMonoStyle.copyWith(color: context.colors.onSurface),
            ),
          ),
          IconButton(
            tooltip: _copied ? 'Copied' : 'Copy',
            onPressed: _copy,
            icon: Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
