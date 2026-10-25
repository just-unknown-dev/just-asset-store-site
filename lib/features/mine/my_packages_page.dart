import 'package:flutter/material.dart';
import 'package:just_asset_store_pages/content.dart';
import 'package:just_signals/just_signals.dart';
import 'package:just_unknown_design/just_unknown_design.dart';
import 'package:just_unknown_design/site_builder.dart' show isoDate;

import '../../core/auth/store_auth.dart';
import '../../core/di/app_config.dart';
import '../../core/notices/notices.dart';
import '../../core/submissions/submissions.dart';
import '../publish/submission_tile.dart';
import '../shared/claim_card.dart';
import '../shared/notice.dart';

/// The signed-in user's claim code, the store's notices to them, what they
/// listed, and every submission they made.
class MyPackagesPage extends StatelessWidget {
  const MyPackagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = getIt<StoreAuth>();
    final submissions = getIt<SubmissionsController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHero(
          eyebrow: MineCopy.eyebrow,
          title: MineCopy.title,
          lede: MineCopy.lede,
          compact: true,
          actions: [
            SiteLink(
              'Publish a package',
              StoreRoutes.publishPath,
              primary: true,
            ),
          ],
        ),
        ContentColumn(
          child: Padding(
            padding: const EdgeInsets.only(bottom: JuSpacing.x16),
            child: SignalBuilder<StoreUser?>(
              signal: auth.user,
              builder: (context, user, _) {
                if (user == null) {
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: SignInCard(auth: auth, body: MineCopy.signInBody),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SignedInAs(auth: auth, user: user),
                      const SizedBox(height: JuSpacing.x4),
                      if (StoreAccess.mayPublish(user.githubId))
                        ClaimCard(user: user)
                      else
                        const Notice(
                          PublishCopy.closedBody,
                          tone: NoticeTone.warning,
                        ),
                      const SizedBox(height: JuSpacing.x10),
                      Text(
                        MineCopy.noticesTitle,
                        style: context.text.headlineSmall,
                      ),
                      const SizedBox(height: JuSpacing.x4),
                      _Notices(controller: getIt<NoticesController>()),
                      const SizedBox(height: JuSpacing.x10),
                      _Listed(controller: submissions),
                      Text('Submissions', style: context.text.headlineSmall),
                      const SizedBox(height: JuSpacing.x4),
                      SubmissionList(controller: submissions),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Notices extends StatelessWidget {
  const _Notices({required this.controller});

  final NoticesController controller;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder<List<StoreNotice>?>(
      signal: controller.mine,
      builder: (context, notices, _) {
        if (notices == null) {
          return const Padding(
            padding: EdgeInsets.all(JuSpacing.x4),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        if (notices.isEmpty) return const Notice(MineCopy.noNotices);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final n in notices)
              Padding(
                padding: const EdgeInsets.only(bottom: JuSpacing.x3),
                child: Notice(
                  '${isoDate(n.at.toLocal())}: ${n.text}',
                  icon: Icons.mark_email_unread_outlined,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The items the user's listed submissions made, each a link to its page.
class _Listed extends StatelessWidget {
  const _Listed({required this.controller});

  final SubmissionsController controller;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder<List<Submission>?>(
      signal: controller.mine,
      builder: (context, mine, _) {
        final ids = {
          for (final s in mine ?? const <Submission>[])
            if (s.status == SubmissionStatus.listed && s.itemId != null)
              s.itemId!,
        };
        if (ids.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: JuSpacing.x10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Listed', style: context.text.headlineSmall),
              const SizedBox(height: JuSpacing.x2),
              for (final id in ids)
                InlineLink(SiteLink(id, StoreRoutes.item(id))),
            ],
          ),
        );
      },
    );
  }
}
