import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../utils/format.dart';

/// Estado global: sessão, dados de referência da família e mês selecionado.
class AppState extends ChangeNotifier {
  AppState(this.api) {
    api.onUnauthorized = logout;
  }

  final ApiClient api;
  static const _tokenKey = 'ff_token';

  bool ready = false;
  Member? me;
  List<Member> members = [];
  List<Account> accounts = [];
  List<Category> categories = [];
  String month = monthKey(DateTime.now());

  /// Incrementado a cada alteração de dados, para as telas recarregarem.
  int revision = 0;

  bool get loggedIn => me != null;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    api.token = prefs.getString(_tokenKey);
    if (api.token != null) {
      try {
        await _loadSession();
      } catch (_) {
        api.token = null;
        me = null;
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final res = await api.post('/auth/login', {'email': email, 'password': password});
    await _startSession(res['token']);
  }

  Future<void> register({required String familyName, required String name, required String email, required String password}) async {
    final res = await api.post('/auth/register', {'familyName': familyName, 'name': name, 'email': email, 'password': password});
    await _startSession(res['token']);
  }

  Future<void> _startSession(String token) async {
    api.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await _loadSession();
    notifyListeners();
  }

  Future<void> _loadSession() async {
    me = Member.fromJson(await api.get('/auth/me'));
    await refreshReference();
  }

  Future<void> logout() async {
    api.token = null;
    me = null;
    members = [];
    accounts = [];
    categories = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }

  /// Recarrega membros, contas e categorias.
  Future<void> refreshReference() async {
    final results = await Future.wait([api.get('/members'), api.get('/accounts'), api.get('/categories')]);
    members = (results[0] as List).map((j) => Member.fromJson(j)).toList();
    accounts = (results[1] as List).map((j) => Account.fromJson(j)).toList();
    categories = (results[2] as List).map((j) => Category.fromJson(j)).toList();
    notifyListeners();
  }

  /// Chame após criar/editar/remover algo.
  Future<void> dataChanged() async {
    revision++;
    await refreshReference();
  }

  void setMonth(String value) {
    month = value;
    notifyListeners();
  }

  void shiftMonth(int delta) {
    final d = DateTime.parse('$month-01');
    setMonth(monthKey(DateTime(d.year, d.month + delta)));
  }

  Member? memberById(int? id) => id == null ? null : members.where((m) => m.id == id).firstOrNull;
  Account? accountById(int? id) => id == null ? null : accounts.where((a) => a.id == id).firstOrNull;
}
