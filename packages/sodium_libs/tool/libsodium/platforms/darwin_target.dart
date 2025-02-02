import 'dart:io';

import '../../../../../tool/util.dart';
import '../github/github_logger.dart';
import 'plugin_target.dart';

enum DarwinPlatform {
  ios('iPhoneOS', true, '-mios-version-min=11.0', 'a'),
  // ignore: constant_identifier_names
  ios_simulator(
    'iPhoneSimulator',
    true,
    '-mios-simulator-version-min=11.0',
    'a',
  ),
  macos('MacOSX', false, '-mmacosx-version-min=10.14', 'dylib');

  final String sdk;
  final bool hasSysroot;
  final String versionParameter;
  final String librarySuffix;

  const DarwinPlatform(
    this.sdk,
    // ignore: avoid_positional_boolean_parameters
    this.hasSysroot,
    this.versionParameter,
    this.librarySuffix,
  );
}

class DarwinTarget extends PluginTarget {
  final DarwinPlatform platform;
  final String architecture;
  final String buildTarget;

  const DarwinTarget({
    required this.platform,
    required this.architecture,
    required this.buildTarget,
  });

  @override
  String get name => '${platform.name}_$architecture';

  @override
  String get suffix => '.tar.gz';

  @override
  Future<void> build({
    required Directory extractDir,
    required Directory artifactDir,
  }) async {
    final buildDir = extractDir.subDir('libsodium-stable');
    final prefixDir = buildDir.subDir('build');

    final environment = await _createBuildEnvironment();

    await run(
      './configure',
      [
        '--host=$buildTarget',
        '--prefix=${prefixDir.path}',
      ],
      workingDirectory: buildDir,
      environment: environment,
    );

    await run(
      'make',
      [
        '-j${Platform.numberOfProcessors}',
        'install',
      ],
      workingDirectory: buildDir,
      environment: environment,
    );

    await _installLibrary(prefixDir, artifactDir);
  }

  Future<Map<String, String>> _createBuildEnvironment() async {
    // path
    final xcodeDir = Directory(await _invoke('xcode-select', const ['-p']));
    final baseDir = xcodeDir
        .subDir('Platforms')
        .subDir('${platform.sdk}.platform')
        .subDir('Developer');
    final binDir = baseDir.subDir('usr').subDir('bin');
    final sbinDir = baseDir.subDir('usr').subDir('sbin');
    final path = [
      binDir.path,
      sbinDir.path,
      Platform.environment['PATH'],
    ];

    // compiler flags
    final ldFlags = [
      '-arch',
      architecture,
      if (platform.hasSysroot) ...[
        '-isysroot',
        baseDir.subDir('SDKs').subDir('${platform.sdk}.sdk').path,
      ],
      platform.versionParameter,
    ];
    final cFlags = ['-Ofast', ...ldFlags];

    // environment
    return {
      'LIBSODIUM_FULL_BUILD': '1',
      'PATH': path.join(':'),
      'CFLAGS': cFlags.join(' '),
      'LDFLAGS': ldFlags.join(' '),
    };
  }

  Future<void> _installLibrary(
    Directory prefixDir,
    Directory artifactDir,
  ) async {
    final source = File(
      await prefixDir
          .subDir('lib')
          .subFile('libsodium.${platform.librarySuffix}')
          .resolveSymbolicLinks(),
    );
    final target = artifactDir.subFile('libsodium.${platform.librarySuffix}');

    GithubLogger.logInfo('Installing ${target.path}');
    await target.parent.create(recursive: true);
    await source.rename(target.path);
  }

  Future<String> _invoke(String executable, List<String> arguments) async {
    final processResult = await Process.run(executable, arguments);
    if (processResult.exitCode != 0) {
      throw ChildErrorException(exitCode);
    }
    return (processResult.stdout as String).trimRight();
  }
}
