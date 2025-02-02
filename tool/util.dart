import 'dart:async';
import 'dart:io';

const _libsodiumSigningKey =
    'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3';

final tarFileRegexp = RegExp(r'.*\.tar(?:\.\w+)?$');

class ChildErrorException implements Exception {
  final int exitCode;

  ChildErrorException(this.exitCode);

  @override
  String toString() => 'Subprocess failed with exit code $exitCode';
}

class StatusCodeException implements Exception {
  final int statusCode;

  StatusCodeException(this.statusCode);

  @override
  String toString() => 'Request failed with status code $statusCode';
}

Future<void> run(
  String executable,
  List<String> arguments, {
  bool runInShell = false,
  Directory? workingDirectory,
  Map<String, String>? environment,
}) async {
  final pwdMsg =
      workingDirectory != null ? ' (in ${workingDirectory.path})' : '';
  final envMsg = environment != null ? ' with environment:' : '';
  stdout.writeln('>> Running $executable ${arguments.join(' ')}$pwdMsg$envMsg');
  if (environment != null) {
    for (final entry in environment.entries) {
      stdout.writeln('>>> ${entry.key}: ${entry.value}');
    }
  }
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory?.path,
    environment: environment,
    mode: ProcessStartMode.inheritStdio,
    runInShell: runInShell,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw ChildErrorException(exitCode);
  }
}

Future<void> verify(
  File file, [
  String publicKey = _libsodiumSigningKey,
]) async {
  stdout.writeln('> Checking signature of ${file.path}');
  if (Platform.environment['MINISIGN_DOCKER'] == 'true') {
    final filename = file.uri.pathSegments.last;
    await run('docker', [
      'run',
      '--rm',
      '-v',
      '${file.path}:/src/$filename:ro',
      '-v',
      '${file.path}.minisig:/src/$filename.minisig:ro',
      'jedisct1/minisign',
      '-P',
      publicKey,
      '-Vm',
      '/src/$filename',
    ]);
  } else {
    await run('minisign', [
      '-P',
      publicKey,
      '-Vm',
      file.path,
    ]);
  }
}

Future<void> sign(File file, File secretKey) async {
  stdout.writeln('> Signing ${file.path}');
  if (Platform.environment['MINISIGN_DOCKER'] == 'true') {
    final filename = file.uri.pathSegments.last;
    await run('docker', [
      'run',
      '--rm',
      '-v',
      '${file.parent.path}:/src/',
      '-v',
      '${secretKey.path}:/run/secrets/minisign.key:ro',
      'jedisct1/minisign',
      '-Ss',
      '/run/secrets/minisign.key',
      '-m',
      '/src/$filename',
    ]);
  } else {
    await run('minisign', [
      '-Ss',
      secretKey.path,
      '-m',
      file.path,
    ]);
  }
}

Future<void> extract({
  required File archive,
  required Directory outDir,
}) async {
  stdout.writeln('> Unpacking ${archive.path} to ${outDir.path}');
  if (archive.path.contains(tarFileRegexp)) {
    await run(
      'tar',
      ['-xvf', archive.path],
      workingDirectory: outDir,
    );
  } else {
    await run('7z', [
      'x',
      '-y',
      '-o${outDir.path}',
      archive.path,
    ]);
  }
}

Future<void> compress({
  required Directory inDir,
  required File archive,
}) async {
  stdout.writeln('> Compression ${inDir.path} into ${archive.path}');
  if (archive.path.contains(tarFileRegexp)) {
    await run(
      'tar',
      ['-cavf', archive.path, '.'],
      workingDirectory: inDir,
    );
  } else {
    await run(
      '7z',
      ['a', '-y', archive.path, '.'],
      workingDirectory: inDir,
    );
  }
}

extension FileSystemEntityX on FileSystemEntity {
  Future<void> assertExists() async {
    if (!await exists()) {
      throw Exception('File $path does not exists');
    }
  }
}

extension DirectoryX on Directory {
  Directory subDir(String path) => Directory.fromUri(uri.resolve(path));

  File subFile(String path) => File.fromUri(uri.resolve(path));
}

typedef HeaderExtractor = FutureOr<void> Function(HttpHeaders headers);

extension HttpClientX on HttpClient {
  Future<File> download(
    Directory targetDir,
    Uri uri, {
    bool withSignature = false,
  }) async {
    final request = await getUrl(uri);
    final response = await request.close();
    if (response.statusCode >= 300) {
      throw StatusCodeException(response.statusCode);
    }

    final outFile = targetDir.subFile(uri.pathSegments.last);
    final outSink = outFile.openWrite();
    await response.pipe(outSink);

    if (withSignature) {
      await download(
        targetDir,
        uri.replace(path: "${uri.path}.minisig"),
      );
    }

    return outFile;
  }
}
