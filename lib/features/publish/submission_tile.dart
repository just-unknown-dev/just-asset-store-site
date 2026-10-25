import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_asset_store_pages/content.dart';
import 'package:just_signals/just_signals.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

import '../../core/auth/store_auth.dart';
import '../../core/submissions/submissions.dart';
import '../shared/notice.dart';

/// One submission and what the store said about it.
class SubmissionTile extends StatelessWidget {
  const SubmissionTile(this.submission, {super.key});

  final Submission submission;

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final (label, color, icon) = switch (s.status) {
      SubmissionStatus.pending => (
        'Waiting for the next check',
        context.tokens.textMuted,
        Icons.schedule_rounded,
      ),
      SubmissionStatus.listed => (
        'Listed',
        context.colors.primary,
        Icons.check_circle_rounded,
      ),
      SubmissionStatus.held => (
        'Waiting for a maintainer',
        context.tokens.textMuted,
        Icons.hourglass_top_rounded,
      ),
      SubmissionStatus.refused => (
        'Refused',
        context.colors.error,
        Icons.cancel_rounded,
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: JuSpacing.x3),
      padding: const EdgeInsets.all(JuSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(JuRadii.sm),
        border: Border.all(color: context.tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: JuSpacing.x3,
            runSpacing: JuSpacing.x2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(label, color: color, icon: icon),
              Text(
                s.repo.replaceFirst('https://github.com/', ''),
                style: juMonoStyle.copyWith(
                  fontSize: 13,
                  color: context.colors.onSurface,
                ),
              ),
            ],
          ),
          if (s.message != null) ...[
            const SizedBox(height: JuSpacing.x3),
            SelectableText(s.message!, style: context.text.bodySmall),
          ],
          if (s.status == SubmissionStatus.listed && s.itemId != null) ...[
            const SizedBox(height: JuSpacing.x2),
            InlineLink(SiteLink('See it in the store', StoreRoutes.item(s.itemId!))),
          ],
        ],
      ),
    );
  }
}

/// The signed-in user's submissions, newest first ([limit] of them when
/// set).
class SubmissionList extends StatelessWidget {
  const SubmissionList({super.key, required this.controller, this.limit});

  final SubmissionsController controller;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder2<List<Submission>?, String?>(
      signal1: controller.mine,
      signal2: controller.error,
      builder: (context, mine, error, _) {
        if (error != null) return Notice(error, tone: NoticeTone.error);
        if (mine == null) {
          return const Padding(
            padding: EdgeInsets.all(JuSpacing.x6),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        if (mine.isEmpty) {
          return const Notice('You haven’t submitted anything yet.');
        }
        final shown = limit == null ? mine : mine.take(limit!).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in shown) SubmissionTile(s),
            if (shown.length < mine.length)
              Align(
                alignment: Alignment.centerLeft,
                child: InlineLink(
                  SiteLink('All ${mine.length} submissions', StoreRoutes.minePath),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "Sign in with GitHub", with why.
class SignInCard extends StatelessWidget {
  const SignInCard({super.key, required this.auth, required this.body});

  final StoreAuth auth;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(JuSpacing.x6),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(JuRadii.md),
        border: Border.all(color: context.tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body, style: context.text.bodyMedium),
          const SizedBox(height: JuSpacing.x5),
          // Firebase may still be starting: whether sign-in works here is
          // known once it has.
          SignalBuilder<bool>(
            signal: auth.ready,
            builder: (context, ready, _) => !auth.available
                ? const Notice(
                    'Sign-in isn’t set up on this copy of the store yet.',
                    tone: NoticeTone.warning,
                  )
                : FilledButton.icon(
                    onPressed: auth.signIn,
                    icon: const Icon(Icons.code_rounded, size: 18),
                    label: const Text('Sign in with GitHub'),
                  ),
          ),
          SignalBuilder<String?>(
            signal: auth.error,
            builder: (context, error, _) => error == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: JuSpacing.x4),
                    child: Notice(error, tone: NoticeTone.error),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Signed in as …, with a sign-out link.
class SignedInAs extends StatelessWidget {
  const SignedInAs({super.key, required this.auth, required this.user});

  final StoreAuth auth;
  final StoreUser user;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: JuSpacing.x2,
      children: [
        Text('Signed in as ${user.label}.', style: context.text.bodySmall),
        TextButton(
          onPressed: () async {
            await auth.signOut();
            if (context.mounted) context.go(StoreRoutes.publishPath);
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
