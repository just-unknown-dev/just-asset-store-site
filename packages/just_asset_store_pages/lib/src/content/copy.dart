/// The store's words as data: the static pages and the publish app render
/// the same ones.
library;

import 'access.dart';
import 'links.dart';

/// A titled point with an optional command.
final class CopyPoint {
  const CopyPoint(this.title, this.body, {this.code, this.icon});

  final String title;
  final String body;

  /// A command to show under it.
  final String? code;

  /// Which picture the app draws (`copyIcon` in the app).
  final String? icon;
}

/// A heading and its paragraphs and bullets.
final class CopySection {
  const CopySection(this.heading, this.paragraphs, {this.bullets = const []});

  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;
}

abstract final class HomeCopy {
  static const String eyebrow = 'Just Asset Store';
  static const String title = 'Art, kits and tools for the Just Game Engine.';
  static const String lede =
      'Everything here installs into a project with one command, or from the '
      'editor’s store window. Downloads come straight from each package’s '
      'GitHub release, checked against the fingerprint the store recorded.';

  static const String featuredTitle = 'Featured';
  static const String categoriesTitle = 'Browse by category';
  static const String recentTitle = 'New & updated';
  static const String toolsTitle = 'Editor tools';
  static const String kitsTitle = 'Genre kits';
  static const String artTitle = 'Art & sound';
  static const String templatesTitle = 'Project templates';
  static const String seeAll = 'See all';
  static const String seeIt = 'See it';

  static const String howEyebrow = 'How it works';
  static const String howTitle = 'One catalog, two ways in.';
  static const List<CopyPoint> how = [
    CopyPoint(
      'Install with just',
      'Run one command in your project. The just tool downloads the package, '
          'checks it and wires it into your pubspec and the editor.',
      code: 'just add just_sprite_editor',
      icon: 'terminal',
    ),
    CopyPoint(
      'Or from the editor',
      'The Store window in the Just Game Engine editor lists the same catalog. '
          'Pick a package, read what it changes, and install it there.',
      icon: 'editor',
    ),
    CopyPoint(
      'Checked downloads',
      'Each version is pinned by its SHA-256 when the store lists it, from a '
          'release GitHub won’t let anyone change. A file that doesn’t match '
          'is refused, on your machine and your teammates’.',
      icon: 'shield',
    ),
  ];

  static const String cliTitle = 'Get the just tool';
  static const String cliBody =
      'just installs packages from the command line. It needs Dart (it comes '
      'with Flutter).';
}

/// The item page's install box.
abstract final class ItemCopy {
  static const String installTitle = 'Install';
  static const String editorTab = 'Editor';
  static const String cliTab = 'Command line';

  /// How to install the item called [name] from the editor.
  static List<String> editorSteps(String name) => [
    'Open your project in the Just Game Engine editor.',
    'Open the Asset Store: the shop button under the transform tools, or '
        'Ctrl+Shift+G.',
    'Search for “$name” and press Install.',
  ];

  static const String cliHint = 'Run it in your project’s folder.';
  static const String noJust = 'No just yet?';
  static const String getJust = 'Get the just tool';
}

abstract final class SearchCopy {
  static const String title = 'Search';
  static const String lede = 'Every package in the store, by name, tag or '
      'publisher.';
  static const String placeholder = 'Search packages';
  static const String noScript =
      'Searching needs JavaScript. Every package is also listed under its '
      'category.';
  static const String empty = 'Nothing matches that. Try another word.';
}

abstract final class PublishCopy {
  static const String eyebrow = 'Publish';
  static const String title = StoreAccess.openPublishing
      ? 'Share your package with every Just developer.'
      : 'Publishing to the Just Asset Store';
  static const String lede = StoreAccess.openPublishing
      ? 'Release it on GitHub, submit its repository here, and the store '
            'checks it and lists it. Your files stay on GitHub; the store '
            'records where they are and what they must look like.'
      : 'For now the store lists Just Unknown’s own packages, released from '
            'the ${StoreAccess.officialLogin} GitHub account. Publishing opens '
            'to everyone in a later version; this is how it works.';

  /// What a signed-in account that may not publish yet is told.
  static const String closedBody =
      'Only Just Unknown’s own account (${StoreAccess.officialLogin}) '
      'publishes to the store for now. Publishing opens to everyone in a '
      'later version.';

  static const String stepsTitle = 'From your repository to the store';
  static const List<CopyPoint> steps = [
    CopyPoint(
      'Make a package',
      'A Dart package with a just_store.json beside its pubspec: its id, '
          'name, kind, category, and what its code does. Start from the '
          'store’s item template.',
      icon: 'package',
    ),
    CopyPoint(
      'Turn on immutable releases',
      'In the repository’s Settings → General → Releases. The store lists '
          'only releases whose files can never be swapped.',
      icon: 'shield',
    ),
    CopyPoint(
      'Add your claim code',
      'Sign in below to see it, and save it as the repository variable '
          'JUST_STORE_CLAIM. Only someone who can push to the repository can '
          'put it there, so it tells the store the package is yours.',
      icon: 'key',
    ),
    CopyPoint(
      'Release it',
      'Tag a version (v1.0.0). The item template’s release workflow packs the '
          'package, attaches the archive and just_release.json, and publishes '
          'the release.',
      code: 'git tag v1.0.0 && git push --tags',
      icon: 'tag',
    ),
    CopyPoint(
      'Check it',
      'Run the same checks the store runs, in your package’s folder.',
      code: 'just store validate .',
      icon: 'check',
    ),
    CopyPoint(
      'Submit it here',
      'Give your repository’s address. The store checks the release within '
          'the hour, and lists it, or tells you why not. After that it finds '
          'your new releases by itself, every hour.',
      icon: 'upload',
    ),
  ];

  static const String formTitle = 'Submit a package';
  static const String signInBody =
      'Sign in with GitHub. The store reads only your public profile; your '
      'claim code is what shows the repository is yours.';
  static const String terms =
      'I have read the content policy, and this package and everything in it '
      'is mine to share under its licence.';
  static const String templateLink = StoreLinks.itemTemplate;

  static const String claimTitle = 'Your claim code';
  static const String claimBody =
      'Save it in each repository you publish from, as the Actions variable '
      'JUST_STORE_CLAIM (Settings → Secrets and variables → Actions → '
      'Variables). It is the same for all your packages, and isn’t a secret.';
}

/// Why someone reports a package. The ids are the ones `firestore.rules`
/// and the backend accept.
enum ReportReason {
  malware('malware', 'It harms computers (malware, a hidden download)'),
  stolen('stolen', 'It holds work that isn’t the publisher’s to share'),
  broken('broken', 'It doesn’t install or doesn’t work'),
  inappropriate('inappropriate', 'It breaks the content policy'),
  other('other', 'Something else');

  const ReportReason(this.id, this.label);

  final String id;
  final String label;
}

abstract final class ReportCopy {
  static const String eyebrow = 'Report';
  static const String title = 'Report a package';
  static const String lede =
      'Tell the store’s maintainers what is wrong. They read every report; '
      'a package can be taken down, or one version withdrawn.';
  static const String signInBody =
      'Sign in with GitHub to report a package, so a maintainer can ask you '
      'about it.';
  static const String detailsLabel = 'What happened (optional)';
  static const int detailsMax = 2000;
  static const String sent =
      'Sent. A maintainer will look at it; thank you.';
  static const String tooSoon =
      'The store takes one report every two minutes. Wait a little, then send '
      'it again.';
  static const String noItem =
      'Open this form from the package’s page (Report this package), so it '
      'knows which package you mean.';
}

abstract final class MineCopy {
  static const String eyebrow = 'Account';
  static const String title = 'My packages';
  static const String lede =
      'Your claim code, what the store said about each submission, and its '
      'notices about your releases.';
  static const String signInBody =
      'Sign in with GitHub to see your claim code and the packages you '
      'submitted.';
  static const String noticesTitle = 'From the store';
  static const String noNotices = 'Nothing new from the store.';
}

abstract final class PolicyCopy {
  /// Shown until the store's owner has reviewed this page.
  static const bool draft = true;
  static const String draftNotice =
      'Draft. Just Unknown must review this policy before community '
      'submissions open.';

  static const String eyebrow = 'Policy';
  static const String title = 'Content policy';
  static const String lede =
      'What may be listed in the Just Asset Store, how packages are checked, '
      'and what happens when one is reported.';

  static const List<CopySection> sections = [
    if (!StoreAccess.openPublishing)
      CopySection('Who publishes', [
        'For now the store lists only Just Unknown’s own packages, released '
            'from the ${StoreAccess.officialLogin} GitHub account. Publishing '
            'opens to everyone in a later version, under the rules below.',
      ]),
    CopySection(
      'What may be listed',
      [
        'Packages made for the Just Game Engine: art and sound, genre kits, '
            'editor tools, runtime libraries and project templates.',
      ],
      bullets: [
        'Its source is a public GitHub repository you can push to, with '
            'immutable releases turned on.',
        'Each version is a GitHub release made by the store’s release '
            'workflow, with just_release.json beside its archive, carrying '
            'your claim code.',
        'It names its licence, and everything in it is yours to share under '
            'that licence.',
      ],
    ),
    CopySection(
      'What may not',
      ['A package is refused or taken down when it:'],
      bullets: [
        'does something its just_store.json doesn’t declare — connecting to '
            'the internet, changing files outside the project, running other '
            'programs, bringing native code;',
        'holds art, sound, fonts or code that is not the publisher’s to share;',
        'hides what it is, or copies another package’s name or look;',
        'is spam, or exists only to point somewhere else.',
      ],
    ),
    CopySection('Code runs on your machine', [
      'Kits, libraries and editor tools are Dart code. Editor tools run inside '
          'the editor with your permissions; kits and libraries ship inside '
          'your games.',
      'Every version is checked automatically before it is listed — who '
          'published it, the archive’s fingerprint, the files it holds, the '
          'packages it brings from pub.dev — and some wait for a maintainer '
          'first. But a community package is not reviewed by a person. Its '
          'badge says so, and installing it shows what it says it does. Read '
          'that before you install it.',
    ]),
    CopySection('Names', [
      'A package’s id is its Dart package name, first come, first served. Ids '
          'starting with just_ are kept for Just Unknown’s own packages. An '
          'id another repository already uses, or a package on pub.dev '
          'already has, is refused: projects that use that package would get '
          'yours instead.',
    ]),
    CopySection('Reports and takedowns', [
      'Report a package from its page: a maintainer gets the report and '
          'answers it. A package can be taken down, or one version withdrawn; '
          'copies already installed keep working, and projects that have it '
          'are warned.',
      'Copyright holders can also write to ${StoreLinks.email}.',
    ]),
    CopySection('Changes', [
      'This policy may change as the store grows. The date of each change will '
          'be shown here.',
    ]),
  ];
}
