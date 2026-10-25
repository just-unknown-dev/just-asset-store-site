import 'package:flutter/material.dart';
import 'package:just_asset_store_pages/content.dart';
import 'package:just_signals/just_signals.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

import '../../core/auth/store_auth.dart';
import '../../core/di/app_config.dart';
import '../../core/github/repo_precheck.dart';
import '../../core/submissions/submission_rules.dart';
import '../../core/submissions/submissions.dart';
import '../shared/claim_card.dart';
import '../shared/notice.dart';
import '../shared/store_icons.dart';
import 'submission_tile.dart';

/// How to publish, the claim code, and the form that submits a repository.
class PublishPage extends StatelessWidget {
  const PublishPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = getIt<StoreAuth>();
    final submissions = getIt<SubmissionsController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHero(
          eyebrow: PublishCopy.eyebrow,
          title: PublishCopy.title,
          lede: PublishCopy.lede,
          compact: true,
          actions: [
            SiteLink('Item template', PublishCopy.templateLink),
            SiteLink('Content policy', StoreRoutes.policyPath),
          ],
        ),
        SectionBlock(
          title: PublishCopy.stepsTitle,
          content: Column(
            children: [
              for (var i = 0; i < PublishCopy.steps.length; i++)
                _Step(number: i + 1, point: PublishCopy.steps[i]),
            ],
          ),
        ),
        SectionBlock(
          title: PublishCopy.formTitle,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SignalBuilder<StoreUser?>(
              signal: auth.user,
              builder: (context, user, _) => user == null
                  ? SignInCard(auth: auth, body: PublishCopy.signInBody)
                  : !StoreAccess.mayPublish(user.githubId)
                  // The first version: only Just Unknown's own account.
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SignedInAs(auth: auth, user: user),
                        const SizedBox(height: JuSpacing.x4),
                        const Notice(
                          PublishCopy.closedBody,
                          tone: NoticeTone.warning,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SignedInAs(auth: auth, user: user),
                        const SizedBox(height: JuSpacing.x4),
                        ClaimCard(user: user),
                        const SizedBox(height: JuSpacing.x6),
                        SubmitForm(
                          controller: submissions,
                          precheck: getIt<RepoPrecheck>(),
                        ),
                        const SizedBox(height: JuSpacing.x10),
                        Text(
                          'Your submissions',
                          style: context.text.headlineSmall,
                        ),
                        const SizedBox(height: JuSpacing.x4),
                        SubmissionList(controller: submissions, limit: 5),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.point});

  final int number;
  final CopyPoint point;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: JuSpacing.x6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconTile(copyIcon(point.icon)),
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: context.text.labelMedium?.copyWith(
                      color: context.colors.onPrimary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: JuSpacing.x5),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(point.title, style: context.text.titleLarge),
                  const SizedBox(height: JuSpacing.x1),
                  Text(point.body, style: context.text.bodyMedium),
                  if (point.code != null) ...[
                    const SizedBox(height: JuSpacing.x3),
                    CodeCard(point.code!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The repository, a note, and the terms. Before submitting, GitHub is
/// asked what the store will check first ([RepoPrecheck]); what it would
/// refuse stops the form, with why.
class SubmitForm extends StatefulWidget {
  const SubmitForm({
    super.key,
    required this.controller,
    required this.precheck,
  });

  final SubmissionsController controller;
  final RepoPrecheck precheck;

  @override
  State<SubmitForm> createState() => _SubmitFormState();
}

class _SubmitFormState extends State<SubmitForm> {
  final _repo = TextEditingController();
  final _note = TextEditingController();
  bool _agreed = false;
  bool _busy = false;
  String? _repoError;
  String? _error;
  String? _done;
  Precheck? _checked;

  @override
  void dispose() {
    _repo.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _ready =>
      !_busy && _agreed && SubmissionRules.normalizeRepo(_repo.text) != null;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _done = null;
      _checked = null;
    });
    try {
      final repo = SubmissionRules.normalizeRepo(_repo.text)!;
      final parts = Uri.parse(repo).pathSegments;
      final checked = await widget.precheck.check(parts[0], parts[1]);
      if (!mounted) return;
      setState(() => _checked = checked);
      if (checked.blocks) {
        setState(
          () => _error =
              'The store would refuse it as it is. Fix what’s marked, then '
              'submit again.',
        );
        return;
      }
      await widget.controller.submit(repo: _repo.text, note: _note.text);
      if (!mounted) return;
      setState(() {
        _done =
            'Submitted. The store checks it within the hour; its answer '
            'appears below, and in My packages.';
        _repo.clear();
        _note.clear();
        _agreed = false;
      });
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } on Object catch (e) {
      setState(() => _error = 'It could not be submitted: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _repo,
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: (v) => setState(() {
            _repoError = v.trim().isEmpty
                ? null
                : SubmissionRules.repoProblem(v);
          }),
          decoration: InputDecoration(
            labelText: 'Repository',
            hintText: 'https://github.com/you/your-package',
            helperText: 'Its releases must carry your claim code.',
            errorText: _repoError,
            prefixIcon: const Icon(Icons.code_rounded),
          ),
        ),
        const SizedBox(height: JuSpacing.x4),
        TextField(
          controller: _note,
          maxLines: 3,
          maxLength: SubmissionRules.noteMax,
          decoration: const InputDecoration(
            labelText: 'Note for the maintainers (optional)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: JuSpacing.x2),
        CheckboxListTile(
          value: _agreed,
          onChanged: (v) => setState(() => _agreed = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            PublishCopy.terms,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
        ),
        const SizedBox(height: JuSpacing.x4),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _ready ? _submit : null,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_rounded, size: 18),
            label: const Text('Submit for review'),
          ),
        ),
        if (_checked != null) ...[
          const SizedBox(height: JuSpacing.x4),
          PrecheckList(_checked!),
        ],
        if (_error != null) ...[
          const SizedBox(height: JuSpacing.x4),
          Notice(_error!, tone: NoticeTone.error),
        ],
        if (_done != null) ...[
          const SizedBox(height: JuSpacing.x4),
          Notice(_done!, icon: Icons.check_circle_outline_rounded),
        ],
      ],
    );
  }
}

/// What GitHub said, one line each.
class PrecheckList extends StatelessWidget {
  const PrecheckList(this.precheck, {super.key});

  final Precheck precheck;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in precheck.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: JuSpacing.x2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  switch (line.state) {
                    CheckState.ok => Icons.check_circle_rounded,
                    CheckState.unknown => Icons.help_outline_rounded,
                    CheckState.fail => Icons.cancel_rounded,
                  },
                  size: 18,
                  semanticLabel: switch (line.state) {
                    CheckState.ok => 'Good',
                    CheckState.unknown => 'Not checked',
                    CheckState.fail => 'Problem',
                  },
                  color: switch (line.state) {
                    CheckState.ok => context.colors.primary,
                    CheckState.unknown => context.tokens.textMuted,
                    CheckState.fail => context.colors.error,
                  },
                ),
                const SizedBox(width: JuSpacing.x2),
                Expanded(
                  child: Text(line.text, style: context.text.bodySmall),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
