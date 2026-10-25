import 'package:just_asset_store_pages/content.dart';
import 'package:just_di/just_di.dart';
import 'package:just_storage/just_storage.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

import '../auth/store_auth.dart';
import '../github/repo_precheck.dart';
import '../notices/notices.dart';
import '../reports/reports.dart';
import '../router/route_state.dart';
import '../seo/head_binder.dart';
import '../submissions/submissions.dart';

T getIt<T extends Object>({String? instanceName}) =>
    JustDi.get<T>(instanceName: instanceName);

/// Registers the app's singletons. Called once in `main()` before `runApp`;
/// tests pass fakes.
Future<void> setupDependencies({
  JustStandardStorage? storage,
  HeadService? head,
  StoreAuth? auth,
  SubmissionStore? submissions,
  ReportStore? reports,
  NoticeStore? notices,
  RepoPrecheck? precheck,
}) async {
  final store = storage ?? await JustStorage.standard();
  JustDi.registerSingleton<JustStandardStorage>(store);

  final theme = ThemeController(store, storageKey: StoreMeta.themeKey);
  await theme.init();
  JustDi.registerSingleton<ThemeController>(theme);

  final routeState = RouteState();
  JustDi.registerSingleton<RouteState>(routeState);

  final signIn = auth ?? UnavailableAuth();
  JustDi.registerSingleton<StoreAuth>(signIn);

  JustDi.registerSingleton<SubmissionsController>(
    SubmissionsController(signIn, submissions ?? const NoSubmissionStore()),
    dispose: (c) => c.dispose(),
  );
  JustDi.registerSingleton<ReportsController>(
    ReportsController(signIn, reports ?? const NoReportStore()),
  );
  JustDi.registerSingleton<NoticesController>(
    NoticesController(signIn, notices ?? const NoNoticeStore()),
    dispose: (c) => c.dispose(),
  );
  JustDi.registerSingleton<RepoPrecheck>(precheck ?? GitHubPrecheck());

  JustDi.registerSingleton<HeadBinder>(
    HeadBinder(head ?? createHeadService(), routeState),
    dispose: (b) => b.dispose(),
  );
}

/// Tears everything down (tests).
Future<void> resetDependencies() async => JustDi.reset();
