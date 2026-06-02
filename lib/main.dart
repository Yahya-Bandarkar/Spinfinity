import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:spin/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MobileAds.instance.initialize();
  runApp(const SpinApp());
}

String todayDateString() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class SpinApp extends StatelessWidget {
  const SpinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Spin',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
        home: const RootGate(),
      ),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final store = context.read<FirestoreService>();

    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }
        return FutureBuilder<void>(
          future: store.onLoginBootstrap(user),
          builder: (context, initSnapshot) {
            if (initSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (initSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Startup failed: ${initSnapshot.error}'),
                  ),
                ),
              );
            }
            return const HomeScreen();
          },
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().signInWithGoogle();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.casino, size: 72),
              const SizedBox(height: 16),
              const Text('Welcome to Spin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loading ? null : _signIn,
                icon: const Icon(Icons.login),
                label: Text(_loading ? 'Signing in...' : 'Continue with Google'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  InterstitialAd? _interstitial;
  int _tabSwitchCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInterstitial();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  void _onTabChanged(int value) {
    if (value == _index) return;
    setState(() => _index = value);
    _tabSwitchCount++;
    if (_tabSwitchCount % 2 == 0 && _interstitial != null) {
      _interstitial!.show();
      _interstitial!.dispose();
      _interstitial = null;
      _loadInterstitial();
    }
  }

  @override
  void dispose() {
    _interstitial?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pages = [SpinScreen(), WalletScreen(), ProfileScreen()];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTabChanged,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.casino), label: 'Spin'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class SpinScreen extends StatefulWidget {
  const SpinScreen({super.key});

  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen> {
  final rewards = const [10, 25, 50, 100];
  bool _spinning = false;
  String _message = '';
  RewardedAd? _rewardedAd;

  @override
  void initState() {
    super.initState();
    _loadRewarded();
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  Future<void> _spin() async {
    if (_spinning) return;
    setState(() => _spinning = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final service = context.read<FirestoreService>();
      final reward = await service.reserveSpin(uid);

      if (reward == null) {
        setState(() => _message = 'Daily spin limit reached (5/5).');
        return;
      }

      var credited = false;
      Future<void> creditOnce() async {
        if (credited) return;
        credited = true;
        await service.creditSpinReward(uid: uid, reward: reward);
        if (mounted) {
          setState(() => _message = 'You won $reward points!');
        }
      }

      final ad = _rewardedAd;
      if (ad == null) {
        await creditOnce();
        _loadRewarded();
        return;
      }

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          _loadRewarded();
        },
        onAdFailedToShowFullScreenContent: (ad, _) async {
          ad.dispose();
          _rewardedAd = null;
          await creditOnce();
          _loadRewarded();
        },
      );
      await ad.show(onUserEarnedReward: (_, _) async => creditOnce());
    } catch (e) {
      if (mounted) {
        setState(() => _message = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _spinning = false);
      }
    }
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final store = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Spin')),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: store.userStream(uid),
        builder: (context, snapshot) {
          final data = snapshot.data ?? {};
          final spinsToday = (data['spinsToday'] ?? 0) as int;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Reward slots: ${rewards.join(', ')} points'),
                const SizedBox(height: 20),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('Spinning Wheel', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Spins today: $spinsToday / 5'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _spinning ? null : _spin,
                  child: Text(_spinning ? 'Spinning...' : 'Spin Now'),
                ),
                const SizedBox(height: 12),
                Text(_message),
              ],
            ),
          );
        },
      ),
    );
  }
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final upiCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  BannerAd? _banner;

  @override
  void initState() {
    super.initState();
    _banner = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      listener: const BannerAdListener(),
      request: const AdRequest(),
    )..load();
  }

  @override
  void dispose() {
    upiCtrl.dispose();
    amountCtrl.dispose();
    _banner?.dispose();
    super.dispose();
  }

  Future<void> _openWithdrawDialog() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final service = context.read<FirestoreService>();
    final formKey = GlobalKey<FormState>();
    upiCtrl.clear();
    amountCtrl.clear();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: upiCtrl,
                decoration: const InputDecoration(labelText: 'UPI ID'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter UPI ID' : null,
              ),
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (INR)'),
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  if (amount == null) return 'Enter valid amount';
                  if (amount < 100) return 'Minimum withdrawal is ₹100';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await service.submitWithdrawal(
                uid: uid,
                upiId: upiCtrl.text.trim(),
                amount: int.parse(amountCtrl.text.trim()),
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Withdrawal request submitted')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final store = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: store.userStream(uid),
        builder: (context, snapshot) {
          final points = (snapshot.data?['points'] ?? 0) as int;
          final rupees = points / 1000.0;

          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Points: $points', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Value: ₹${rupees.toStringAsFixed(2)} (1000 points = ₹1)'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _openWithdrawDialog,
                        child: const Text('Withdraw'),
                      ),
                    ],
                  ),
                ),
              ),
              if (_banner != null)
                SizedBox(
                  width: _banner!.size.width.toDouble(),
                  height: _banner!.size.height.toDouble(),
                  child: AdWidget(ad: _banner!),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final upiEditCtrl = TextEditingController();
  final referralCtrl = TextEditingController();
  BannerAd? _banner;

  @override
  void initState() {
    super.initState();
    _banner = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      listener: const BannerAdListener(),
      request: const AdRequest(),
    )..load();
  }

  @override
  void dispose() {
    upiEditCtrl.dispose();
    referralCtrl.dispose();
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final store = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthService>().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: store.userStream(user.uid),
        builder: (context, snapshot) {
          final data = snapshot.data ?? {};
          final upi = (data['upiId'] ?? '') as String;
          final referralCode = (data['myReferralCode'] ?? '') as String;
          final referredBy = data['referredBy'];

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Name: ${data['name'] ?? ''}'),
                    Text('Email: ${data['email'] ?? ''}'),
                    Text('UID: ${data['uid'] ?? ''}'),
                    const SizedBox(height: 16),
                    Text('UPI ID: ${upi.isEmpty ? 'Not set' : upi}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: upiEditCtrl,
                            decoration: const InputDecoration(labelText: 'Update UPI ID'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final value = upiEditCtrl.text.trim();
                            await store.updateUpi(user.uid, value);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('UPI updated')),
                              );
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('My referral code: $referralCode', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Referred by: ${referredBy ?? '-'}'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: referralCtrl,
                      decoration: const InputDecoration(labelText: 'Enter referral code'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final result = await store.applyReferralCode(
                          uid: user.uid,
                          code: referralCtrl.text.trim().toUpperCase(),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
                        }
                      },
                      child: const Text('Apply Code'),
                    ),
                  ],
                ),
              ),
              if (_banner != null)
                SizedBox(
                  width: _banner!.size.width.toDouble(),
                  height: _banner!.size.height.toDouble(),
                  child: AdWidget(ad: _banner!),
                ),
            ],
          );
        },
      ),
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Google sign-in canceled');
    }
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _random = Random();

  DocumentReference<Map<String, dynamic>> userDoc(String uid) => _db.collection('users').doc(uid);

  Stream<Map<String, dynamic>?> userStream(String uid) {
    return userDoc(uid).snapshots().map((doc) => doc.data());
  }

  Future<void> onLoginBootstrap(User firebaseUser) async {
    final doc = userDoc(firebaseUser.uid);
    final snap = await doc.get();
    if (!snap.exists) {
      final code = await _generateUniqueReferralCode(firebaseUser.uid);
      final data = <String, dynamic>{
        'name': firebaseUser.displayName ?? 'User',
        'email': firebaseUser.email ?? '',
        'uid': firebaseUser.uid,
        'points': 0,
        'totalEarnings': 0,
        'todayEarning': 0,
        'referredBy': null,
        'myReferralCode': code,
        'upiId': '',
        'lastLoginDate': '',
        'spinsToday': 0,
        'lastSpinDate': '',
        'referralCodeApplied': false,
      };
      await doc.set(data);
      await _db.collection('referralCodes').doc(code).set({'uid': firebaseUser.uid});
    }
    await _applyDailyBonus(firebaseUser.uid);
  }

  Future<void> _applyDailyBonus(String uid) async {
    final today = todayDateString();
    await _db.runTransaction((tx) async {
      final ref = userDoc(uid);
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data()!;
      final lastLoginDate = (data['lastLoginDate'] ?? '') as String;
      if (lastLoginDate == today) return;

      final bonus = (1 + _random.nextInt(3)) * 1000;
      final currentPoints = (data['points'] ?? 0) as int;
      final currentTotal = (data['totalEarnings'] ?? 0) as int;

      tx.update(ref, {
        'points': currentPoints + bonus,
        'totalEarnings': currentTotal + bonus,
        'todayEarning': bonus,
        'lastLoginDate': today,
      });
    });
  }

  Future<int?> reserveSpin(String uid) async {
    final today = todayDateString();
    return _db.runTransaction<int?>((tx) async {
      final ref = userDoc(uid);
      final snap = await tx.get(ref);
      if (!snap.exists) return null;

      final data = snap.data()!;
      var spinsToday = (data['spinsToday'] ?? 0) as int;
      final lastSpinDate = (data['lastSpinDate'] ?? '') as String;

      if (lastSpinDate != today) {
        spinsToday = 0;
      }
      if (spinsToday >= 5) return null;

      final rewardOptions = [10, 25, 50, 100];
      final reward = rewardOptions[_random.nextInt(rewardOptions.length)];

      tx.update(ref, {
        'spinsToday': spinsToday + 1,
        'lastSpinDate': today,
      });

      return reward;
    });
  }

  Future<void> creditSpinReward({required String uid, required int reward}) async {
    final ref = userDoc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;

      final points = (data['points'] ?? 0) as int;
      final total = (data['totalEarnings'] ?? 0) as int;
      final todayEarn = (data['todayEarning'] ?? 0) as int;

      tx.update(ref, {
        'points': points + reward,
        'totalEarnings': total + reward,
        'todayEarning': todayEarn + reward,
      });
    });
  }

  Future<void> submitWithdrawal({
    required String uid,
    required String upiId,
    required int amount,
  }) async {
    await _db.collection('withdrawalRequests').add({
      'uid': uid,
      'upiId': upiId,
      'amount': amount,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await userDoc(uid).update({'upiId': upiId});
  }

  Future<void> updateUpi(String uid, String upiId) async {
    await userDoc(uid).update({'upiId': upiId});
  }

  Future<String> applyReferralCode({required String uid, required String code}) async {
    if (code.isEmpty) return 'Enter referral code';

    return _db.runTransaction<String>((tx) async {
      final meRef = userDoc(uid);
      final mySnap = await tx.get(meRef);
      if (!mySnap.exists) return 'User not found';

      final myData = mySnap.data()!;
      final alreadyApplied = (myData['referralCodeApplied'] ?? false) as bool;
      if (alreadyApplied || myData['referredBy'] != null) {
        return 'Referral already used';
      }

      final codeRef = _db.collection('referralCodes').doc(code);
      final codeSnap = await tx.get(codeRef);
      if (!codeSnap.exists) return 'Invalid referral code';

      final referrerUid = (codeSnap.data()!['uid'] ?? '') as String;
      if (referrerUid.isEmpty || referrerUid == uid) return 'Invalid referral code';

      final referrerRef = userDoc(referrerUid);
      final referrerSnap = await tx.get(referrerRef);
      if (!referrerSnap.exists) return 'Referrer not found';

      final myPoints = (myData['points'] ?? 0) as int;
      final refData = referrerSnap.data()!;
      final refPoints = (refData['points'] ?? 0) as int;

      tx.update(meRef, {
        'referredBy': code,
        'referralCodeApplied': true,
        'points': myPoints + 2000,
      });
      tx.update(referrerRef, {'points': refPoints + 2000});

      return 'Referral applied. ₹2 credited to both users.';
    });
  }

  Future<String> _generateUniqueReferralCode(String uid) async {
    String candidate = uid.substring(0, min(6, uid.length)).toUpperCase();
    var i = 0;
    while (true) {
      final check = await _db.collection('referralCodes').doc(candidate).get();
      if (!check.exists) return candidate;
      i++;
      final suffix = (_random.nextInt(900) + 100).toString();
      candidate = '${uid.substring(0, min(3, uid.length)).toUpperCase()}$suffix$i';
    }
  }
}
