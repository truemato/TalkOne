import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 現在のユーザーを取得
  User? get currentUser => _auth.currentUser;

  // 認証状態の変更を監視
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Googleアカウントでサインイン（シンプル版 - 正常動作していたバージョンに復元）
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('=== Google Sign In Debug Start ===');
      print('Google Sign In開始');
      print('GoogleSignIn設定: ${_googleSignIn.toString()}');
      
      // Google認証フローを開始
      print('Google認証フロー開始...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().catchError((error) {
        print('❌ Google Sign Inエラー: $error');
        if (error.toString().contains('sign_in_failed')) {
          print('Google Play Servicesの問題またはOAuth設定の問題');
        }
        return null;
      });
      
      if (googleUser == null) {
        print('❌ Googleサインインがキャンセルされました');
        print('考えられる原因:');
        print('1. ユーザーがキャンセルボタンを押した');
        print('2. Google Play Services が利用できない');
        print('3. OAuth設定が正しくない');
        print('4. エミュレーターにGoogleアカウントが設定されていない');
        return null;
      }

      print('✅ Google認証成功: ${googleUser.email}');
      print('ユーザーID: ${googleUser.id}');
      print('表示名: ${googleUser.displayName}');

      // Google認証の詳細を取得
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase認証用のクレデンシャルを作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebaseにサインイン
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // 既存プロフィールの確認（上書きを絶対に防ぐ）
      await _ensureUserProfileExists(userCredential.user!);

      print('✅ Firebase認証成功: ${userCredential.user?.uid}');
      print('=== Google Sign In Debug End ===');
      return userCredential;
    } catch (e) {
      print('❌ Google Sign Inエラー: $e');
      print('エラータイプ: ${e.runtimeType}');
      if (e.toString().contains('DEVELOPER_ERROR')) {
        print('🔧 DEVELOPER_ERROR: SHA-1フィンガープリントまたはOAuth設定を確認してください');
      } else if (e.toString().contains('SIGN_IN_CANCELLED')) {
        print('👤 SIGN_IN_CANCELLED: ユーザーがサインインをキャンセルしました');
      } else if (e.toString().contains('SIGN_IN_FAILED')) {
        print('⚠️ SIGN_IN_FAILED: Google Play Servicesの問題の可能性があります');
      }
      print('=== Google Sign In Debug End ===');
      return null;
    }
  }

  // Apple IDでサインイン（エラー1000対応版）
  Future<UserCredential?> signInWithApple() async {
    try {
      print('🍎 Apple Sign In開始');
      print('Bundle ID: com.truemato.TalkOne');
      
      // Apple認証が利用可能かチェック
      final isAvailable = await SignInWithApple.isAvailable();
      print('Apple Sign In可用性: $isAvailable');
      if (!isAvailable) {
        print('❌ Apple Sign Inが利用できません');
        throw Exception('Apple Sign Inがサポートされていません');
      }
      
      // Apple認証フローを開始
      print('🔑 Apple認証ダイアログを表示中...');
      print('Service ID 設定状況:');
      print('- iOS: ネイティブ認証（Service ID不要）');
      print('- Bundle ID: com.truemato.TalkOne');
      print('- Entitlements: com.apple.developer.applesignin');
      
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        // iOS用：Service ID は不要（ネイティブ認証）
        // webAuthenticationOptions は Android 用のみ
      );
      
      print('✅ Apple認証成功: ${appleCredential.userIdentifier}');
      print('Email: ${appleCredential.email ?? "なし"}');
      print('Name: ${appleCredential.givenName ?? ""} ${appleCredential.familyName ?? ""}');
      print('Identity Token: ${appleCredential.identityToken != null ? "取得済み" : "なし"}');
      print('Authorization Code: ${appleCredential.authorizationCode != null ? "取得済み" : "なし"}');
      
      // トークンの確認
      if (appleCredential.identityToken == null) {
        print('❌ Identity Tokenが空です');
        throw Exception('Apple認証でIdentity Tokenが取得できませんでした');
      }
      
      if (appleCredential.authorizationCode == null) {
        print('❌ Authorization Codeが空です');
        throw Exception('Apple認証でAuthorization Codeが取得できませんでした');
      }
      
      // Firebase認証用のクレデンシャルを作成
      print('🔗 Firebase認証クレデンシャル作成中...');
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      
      // Firebaseにサインイン
      print('🔥 Firebase認証実行中...');
      final UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);
      
      print('✅ Firebase認証成功: ${userCredential.user?.uid}');
      print('Firebase Email: ${userCredential.user?.email ?? "なし"}');
      
      // 既存プロフィールの確認（上書きを絶対に防ぐ）
      await _ensureUserProfileExists(userCredential.user!);
      
      print('✅ Apple Sign In完了: ${userCredential.user?.uid}');
      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      print('❌ Apple認証例外詳細:');
      print('Error Code: ${e.code}');
      print('Error Message: ${e.message}');
      
      // エラーコード1000の詳細処理
      if (e.code == AuthorizationErrorCode.unknown) {
        print('🔧 エラー1000: Apple Developer Console設定を確認してください');
        print('確認項目:');
        print('1. Bundle ID: com.truemato.TalkOne がApple Developer Consoleに登録済みか');
        print('2. Sign In with Apple capabilityが有効になっているか');
        print('3. Service IDが正しく設定されているか');
        throw Exception('Apple Developer Console設定エラー (エラー1000)。Bundle ID: com.truemato.TalkOne の設定を確認してください。');
      }
      
      // ユーザーがキャンセルした場合のみnullを返す
      if (e.code == AuthorizationErrorCode.canceled) {
        print('👤 ユーザーがキャンセルしました');
        return null;
      }
      
      // その他のエラーは詳細情報付きで例外として投げる
      throw Exception('Apple Sign-In エラー ${e.code}: ${e.message ?? "不明なエラー"}');
    } catch (e) {
      print('❌ Apple Sign Inエラー: $e');
      print('エラータイプ: ${e.runtimeType}');
      // エラーを再投げして画面で詳細を表示
      rethrow;
    }
  }

  // 匿名認証でサインイン
  Future<UserCredential?> signInAnonymously() async {
    try {
      print('匿名認証開始');
      final UserCredential userCredential = await _auth.signInAnonymously();
      
      // 匿名ユーザーのプロフィールを初期化
      await _ensureUserProfileExists(userCredential.user!);
      
      print('匿名認証成功: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      print('匿名認証エラー: $e');
      return null;
    }
  }

  // 匿名アカウントをApple IDにリンク（データ保持）
  Future<UserCredential?> linkAnonymousWithApple() async {
    try {
      if (currentUser == null || !currentUser!.isAnonymous) {
        print('匿名ユーザーではありません');
        return null;
      }

      print('=== 匿名アカウントからApple IDアカウントへの移行開始 ===');
      final String anonymousUid = currentUser!.uid;
      print('匿名UID: $anonymousUid');
      
      // 匿名ユーザーのデータをバックアップ
      print('📦 匿名ユーザーデータのバックアップ中...');
      final guestData = await _backupAnonymousUserData(anonymousUid);

      // Apple認証が利用可能かチェック
      final isAvailable = await SignInWithApple.isAvailable();
      print('Apple Sign In可用性: $isAvailable');
      if (!isAvailable) {
        print('❌ Apple Sign Inが利用できません');
        throw Exception('Apple Sign Inがサポートされていません');
      }

      // Apple認証フローを開始
      print('🔑 Apple認証ダイアログを表示中...');
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      
      print('✅ Apple認証成功: ${appleCredential.userIdentifier}');

      // Firebase認証用のクレデンシャルを作成
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // 匿名アカウントにApple IDをリンク
      final UserCredential userCredential = await currentUser!.linkWithCredential(oauthCredential);
      
      print('✅ アカウントリンク成功: ${userCredential.user?.uid}');
      
      // データが保持されているか確認（UIDは変わらないはず）
      if (guestData != null) {
        print('✅ ゲストデータが保持されました');
        await _markDataAsMigrated(userCredential.user!.uid);
      }
      
      return userCredential;
    } catch (e) {
      print('❌ Apple IDアカウントリンクエラー: $e');
      
      // 既に同じApple IDでアカウントが存在する場合の処理
      if (e is FirebaseAuthException && e.code == 'credential-already-in-use') {
        print('🔄 既存のApple IDアカウントに移行します');
        
        // 現在の匿名データをバックアップ
        final anonymousUid = currentUser?.uid;
        Map<String, dynamic>? guestData;
        if (anonymousUid != null) {
          guestData = await _backupAnonymousUserData(anonymousUid);
        }
        
        // 既存アカウントでサインイン
        final existingUserCredential = await signInWithApple();
        
        // ゲストデータがあれば、既存ユーザーデータと統合
        if (existingUserCredential != null && guestData != null) {
          await _mergeGuestDataToExistingUser(existingUserCredential.user!.uid, guestData);
        }
        
        return existingUserCredential;
      }
      
      return null;
    }
  }

  // 匿名アカウントをGoogleアカウントにリンク（データ保持）- シンプル版に復元
  Future<UserCredential?> linkAnonymousWithGoogle() async {
    try {
      if (currentUser == null || !currentUser!.isAnonymous) {
        print('匿名ユーザーではありません');
        return null;
      }

      print('=== 匿名アカウントからGoogleアカウントへの移行開始 ===');
      final String anonymousUid = currentUser!.uid;
      print('匿名UID: $anonymousUid');
      
      // 匿名ユーザーのデータをバックアップ
      print('📦 匿名ユーザーデータのバックアップ中...');
      final guestData = await _backupAnonymousUserData(anonymousUid);

      // Google認証フローを開始
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().catchError((error) {
        print('❌ Google Sign Inエラー (リンク): $error');
        return null;
      });
      
      if (googleUser == null) {
        print('Googleサインインがキャンセルされました');
        return null;
      }

      print('✅ Google Sign In成功: ${googleUser.email}');

      // Google認証の詳細を取得
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase認証用のクレデンシャルを作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 匿名アカウントにGoogleアカウントをリンク
      final UserCredential userCredential = await currentUser!.linkWithCredential(credential);
      
      print('✅ アカウントリンク成功: ${userCredential.user?.uid}');
      
      // データが保持されているか確認（UIDは変わらないはず）
      if (guestData != null) {
        print('✅ ゲストデータが保持されました');
        await _markDataAsMigrated(userCredential.user!.uid);
      }
      
      return userCredential;
    } catch (e) {
      print('❌ アカウントリンクエラー: $e');
      
      // 既に同じメールアドレスでアカウントが存在する場合の処理
      if (e is FirebaseAuthException && e.code == 'credential-already-in-use') {
        print('🔄 既存のGoogleアカウントに移行します');
        
        // 現在の匿名データをバックアップ
        final anonymousUid = currentUser?.uid;
        Map<String, dynamic>? guestData;
        if (anonymousUid != null) {
          guestData = await _backupAnonymousUserData(anonymousUid);
        }
        
        // 既存アカウントでサインイン
        final existingUserCredential = await signInWithGoogle();
        
        // ゲストデータがあれば、既存ユーザーデータと統合
        if (existingUserCredential != null && guestData != null) {
          await _mergeGuestDataToExistingUser(existingUserCredential.user!.uid, guestData);
        }
        
        return existingUserCredential;
      }
      
      return null;
    }
  }
  
  // 匿名ユーザーデータのバックアップ
  Future<Map<String, dynamic>?> _backupAnonymousUserData(String anonymousUid) async {
    try {
      print('📋 匿名ユーザーデータ読み取り: $anonymousUid');
      
      // プロフィールデータ取得
      final profileDoc = await _firestore.collection('userProfiles').doc(anonymousUid).get();
      final ratingDoc = await _firestore.collection('userRatings').doc(anonymousUid).get();
      
      if (!profileDoc.exists) {
        print('ℹ️ 匿名ユーザーのプロフィールデータが見つかりません');
        return null;
      }
      
      final profileData = profileDoc.data() as Map<String, dynamic>;
      final ratingData = ratingDoc.exists ? ratingDoc.data() as Map<String, dynamic> : null;
      
      print('✅ バックアップ完了 - プロフィール: ${profileData.keys}, レーティング: ${ratingData?.keys}');
      
      return {
        'profile': profileData,
        'rating': ratingData,
        'originalUid': anonymousUid,
      };
    } catch (e) {
      print('❌ 匿名ユーザーデータバックアップエラー: $e');
      return null;
    }
  }
  
  // データ移行完了フラグの設定
  Future<void> _markDataAsMigrated(String uid) async {
    try {
      await _firestore.collection('userProfiles').doc(uid).update({
        'migratedFromGuest': true,
        'migrationTimestamp': FieldValue.serverTimestamp(),
      });
      print('✅ データ移行フラグ設定完了');
    } catch (e) {
      print('❌ 移行フラグ設定エラー: $e');
    }
  }
  
  // ゲストデータを既存ユーザーにマージ
  Future<void> _mergeGuestDataToExistingUser(String existingUid, Map<String, dynamic> guestData) async {
    try {
      print('🔀 ゲストデータを既存ユーザーにマージ開始: $existingUid');
      
      final guestProfile = guestData['profile'] as Map<String, dynamic>?;
      final guestRating = guestData['rating'] as Map<String, dynamic>?;
      
      if (guestProfile == null) return;
      
      // 既存ユーザーデータを確認
      final existingProfileDoc = await _firestore.collection('userProfiles').doc(existingUid).get();
      final existingRatingDoc = await _firestore.collection('userRatings').doc(existingUid).get();
      
      // 設定可能なデータのみマージ（重要なデータは既存を優先）
      Map<String, dynamic> mergeData = {};
      
      // AIメモリがあれば統合
      if (guestProfile['aiMemory'] != null && guestProfile['aiMemory'].toString().isNotEmpty) {
        mergeData['aiMemory'] = guestProfile['aiMemory'];
      }
      
      // テーマ設定があれば適用
      if (guestProfile['themeIndex'] != null) {
        mergeData['themeIndex'] = guestProfile['themeIndex'];
      }
      
      // アイコン設定があれば適用
      if (guestProfile['iconPath'] != null && guestProfile['iconPath'] != 'aseets/icons/Woman 1.svg') {
        mergeData['iconPath'] = guestProfile['iconPath'];
      }
      
      if (mergeData.isNotEmpty) {
        mergeData['lastMergedFromGuest'] = FieldValue.serverTimestamp();
        await _firestore.collection('userProfiles').doc(existingUid).update(mergeData);
        print('✅ プロフィールデータマージ完了: ${mergeData.keys}');
      }
      
      // レーティングデータの統合（より高い方を採用）
      if (guestRating != null && existingRatingDoc.exists) {
        final existingRatingData = existingRatingDoc.data() as Map<String, dynamic>;
        final guestRatingValue = guestRating['rating'] as int? ?? 1000;
        final existingRatingValue = existingRatingData['rating'] as int? ?? 1000;
        
        if (guestRatingValue > existingRatingValue) {
          await _firestore.collection('userRatings').doc(existingUid).update({
            'rating': guestRatingValue,
            'mergedFromGuest': FieldValue.serverTimestamp(),
          });
          print('✅ より高いゲストレーティングを適用: $guestRatingValue');
        }
      }
      
      print('✅ ゲストデータマージ完了');
      
    } catch (e) {
      print('❌ ゲストデータマージエラー: $e');
    }
  }

  // サインアウト
  Future<void> signOut() async {
    try {
      // Googleサインアウト
      await _googleSignIn.signOut();
      
      // Firebaseサインアウト
      await _auth.signOut();
      
      print('サインアウト成功');
    } catch (e) {
      print('サインアウトエラー: $e');
    }
  }

  // データベースのユーザーデータ確認と適切な移行処理
  Future<void> _ensureUserProfileExists(User user) async {
    try {
      print('=== ユーザーデータ確認・移行処理開始 ===');
      print('ユーザーUID: ${user.uid}');
      print('匿名ユーザー: ${user.isAnonymous}');
      
      final userDoc = _firestore.collection('userProfiles').doc(user.uid);
      final docSnapshot = await userDoc.get();
      
      if (docSnapshot.exists) {
        // 既存ユーザーデータが存在する場合
        print('✅ 既存ユーザーデータが見つかりました: ${user.uid}');
        final existingData = docSnapshot.data() as Map<String, dynamic>;
        print('既存ニックネーム: ${existingData['nickname'] ?? '未設定'}');
        print('既存レーティング確認中...');
        
        // レーティングデータも確認
        final ratingDoc = _firestore.collection('userRatings').doc(user.uid);
        final ratingSnapshot = await ratingDoc.get();
        if (ratingSnapshot.exists) {
          final ratingData = ratingSnapshot.data() as Map<String, dynamic>;
          print('既存レーティング: ${ratingData['rating'] ?? 1000}');
        }
        
        // App Store Guideline 4.8準拠：既存ユーザーにプライバシー設定を追加
        if (!existingData.containsKey('privacySettings')) {
          print('🔐 既存ユーザーにプライバシー設定を追加します');
          await userDoc.update({
            // メールアドレスをFirestoreから完全削除（プライバシー保護）
            'email': FieldValue.delete(),
            
            // プライバシー設定を追加
            'privacySettings': {
              'emailVisible': false, // 強制的に非公開（メール収集なし）
              'dataProcessingConsent': true, // 既存ユーザーは暗黙的同意
              'advertisingConsent': false, // デフォルトで広告拒否
              'advertisingTrackingBlocked': true, // 広告トラッキング明示的ブロック
              'consentTimestamp': FieldValue.serverTimestamp(),
              'consentVersion': '1.0',
              'migrationFromLegacy': true, // レガシーからの移行フラグ
              'authProvider': user.providerData.isNotEmpty 
                  ? user.providerData.first.providerId 
                  : 'unknown',
            },
          });
          print('✅ プライバシー設定追加完了');
        }
        
        print('既存データを使用します');
        return;
      }
      
      // 新規ユーザーの場合：ゲストデータがあれば移行、なければ新規作成
      print('🆕 新規ユーザーです。ゲストデータの確認を行います...');
      
      // 現在のデバイスの匿名ユーザーからデータを移行する機能
      await _migrateFromGuestIfNeeded(user);
      
    } catch (e) {
      print('❌ ユーザーデータ確認エラー: $e');
    }
  }
  
  // ゲストユーザーからのデータ移行処理
  Future<void> _migrateFromGuestIfNeeded(User newUser) async {
    try {
      print('📦 ゲストデータ移行処理開始');
      
      // 現在ローカルに保存されている可能性のあるデータを確認
      // まずは新規プロフィールを作成してから、後でローカルデータで上書きする戦略
      
      await _createNewUserProfile(newUser);
      
      print('✅ 新規ユーザープロフィール作成完了');
      print('💡 ヒント: ローカルデータがある場合は、設定画面から手動で移行してください');
      
    } catch (e) {
      print('❌ ゲストデータ移行エラー: $e');
    }
  }
  
  // 新規ユーザープロフィール作成
  Future<void> _createNewUserProfile(User user) async {
    try {
      print('🎯 新規プロフィール作成: ${user.uid}');
      
      // プロフィール作成（App Store Guideline 4.8準拠）
      final userDoc = _firestore.collection('userProfiles').doc(user.uid);
      await userDoc.set({
        'nickname': 'My Name', // プライバシー保護のためデフォルト匿名名
        'email': null, // メールアドレスは一切収集しない（プライバシー保護）
        'iconPath': 'aseets/icons/Woman 1.svg',
        'gender': null,
        'birthday': null,
        'comment': null,
        'aiMemory': null,
        'themeIndex': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isAnonymous': user.isAnonymous,
        'migratedFromGuest': false, // 移行フラグ
        
        // App Store Guideline 4.8準拠のプライバシー設定
        'privacySettings': {
          'emailVisible': false, // 強制的に非公開（メール収集しないため）
          'dataProcessingConsent': true, // ログイン時点で暗黙的同意
          'advertisingConsent': false, // デフォルトで広告拒否（同意なしでは収集しない）
          'advertisingTrackingBlocked': true, // 広告トラッキングを明示的にブロック
          'consentTimestamp': FieldValue.serverTimestamp(),
          'consentVersion': '1.0',
          'authProvider': user.providerData.isNotEmpty 
              ? user.providerData.first.providerId 
              : 'anonymous',
        },
      });

      // レーティング初期化
      final ratingDoc = _firestore.collection('userRatings').doc(user.uid);
      await ratingDoc.set({
        'rating': 1000, // 初期レーティング
        'totalGames': 0,
        'winStreak': 0,
        'maxWinStreak': 0,
        'lastGameAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ 新規プロフィール・レーティング作成完了');
      
    } catch (e) {
      print('❌ 新規プロフィール作成エラー: $e');
      rethrow;
    }
  }

  // 匿名ユーザーかどうかを確認
  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  // サインイン済みかどうかを確認
  bool get isSignedIn => currentUser != null;

  // Googleアカウントでサインイン済みかどうかを確認
  bool get isGoogleSignedIn => currentUser != null && !currentUser!.isAnonymous && currentUser!.email != null;
  
  // Apple IDでサインイン済みかどうかを確認
  bool get isAppleSignedIn => currentUser != null && !currentUser!.isAnonymous && 
      currentUser!.providerData.any((provider) => provider.providerId == 'apple.com');
}