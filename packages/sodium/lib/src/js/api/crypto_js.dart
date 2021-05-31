import 'package:meta/meta.dart';

import '../../api/auth.dart';
import '../../api/box.dart';
import '../../api/crypto.dart';
import '../../api/generic_hash.dart';
import '../../api/pwhash.dart';
import '../../api/secret_box.dart';
import '../../api/secret_stream.dart';
import '../../api/short_hash.dart';
import '../../api/sign.dart';
import '../bindings/sodium.js.dart' hide SecretBox;
import 'auth_js.dart';
import 'box_js.dart';
import 'generic_hash_js.dart';
import 'pwhash_js.dart';
import 'secret_box_js.dart';
import 'secret_stream_js.dart';
import 'short_hash_js.dart';
import 'sign_js.dart';

@internal
class CryptoJS implements Crypto {
  final LibSodiumJS sodium;

  CryptoJS(this.sodium);

  @override
  late final SecretBox secretBox = SecretBoxJS(sodium);

  @override
  late final SecretStream secretStream = SecretStreamJS(sodium);

  @override
  late final Auth auth = AuthJS(sodium);

  @override
  late final Box box = BoxJS(sodium);

  @override
  late final Sign sign = SignJS(sodium);

  @override
  late final GenericHash genericHash = GenericHashJS(sodium);

  @override
  late final ShortHash shortHash = ShortHashJS(sodium);

  @override
  late final Pwhash pwhash = PwhashJS(sodium);
}
