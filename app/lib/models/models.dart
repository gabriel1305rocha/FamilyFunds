import '../utils/format.dart';

typedef Json = Map<String, dynamic>;

class Member {
  Member({required this.id, required this.name, required this.color, required this.role, this.email, this.hasLogin = false, this.familyName});

  final int id;
  final String name;
  final String color;
  final String role;
  final String? email;
  final bool hasLogin;
  final String? familyName;

  bool get isOwner => role == 'owner';

  factory Member.fromJson(Json j) => Member(
        id: j['id'],
        name: j['name'],
        color: j['color'] ?? '#1E88E5',
        role: j['role'] ?? 'member',
        email: j['email'],
        hasLogin: j['has_login'] ?? false,
        familyName: j['family_name'],
      );
}

enum AccountType {
  checking('Conta corrente'),
  savings('Poupança'),
  creditCard('Cartão de crédito'),
  cash('Dinheiro'),
  investment('Investimento');

  const AccountType(this.label);
  final String label;

  String get api => this == AccountType.creditCard ? 'credit_card' : name;
  static AccountType parse(String v) => v == 'credit_card' ? AccountType.creditCard : AccountType.values.byName(v);
}

class Account {
  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.color,
    this.ownerId,
    this.institution,
    this.creditLimit,
    this.closingDay,
    this.dueDay,
    this.usedLimit,
    this.availableLimit,
    this.utilization,
    this.currentBill,
  });

  final int id;
  final String name;
  final AccountType type;
  final double balance;
  final String color;
  final int? ownerId;
  final String? institution;
  final double? creditLimit;
  final int? closingDay;
  final int? dueDay;
  final double? usedLimit;
  final double? availableLimit;
  final double? utilization;
  final double? currentBill;

  bool get isCard => type == AccountType.creditCard;

  factory Account.fromJson(Json j) => Account(
        id: j['id'],
        name: j['name'],
        type: AccountType.parse(j['type']),
        balance: toDouble(j['balance']),
        color: j['color'] ?? '#00A86B',
        ownerId: j['owner_id'],
        institution: j['institution'],
        creditLimit: j['credit_limit'] == null ? null : toDouble(j['credit_limit']),
        closingDay: j['closing_day'],
        dueDay: j['due_day'],
        usedLimit: j['used_limit'] == null ? null : toDouble(j['used_limit']),
        availableLimit: j['available_limit'] == null ? null : toDouble(j['available_limit']),
        utilization: j['utilization'] == null ? null : toDouble(j['utilization']),
        currentBill: j['current_bill'] == null ? null : toDouble(j['current_bill']['total']),
      );
}

class Category {
  Category({required this.id, required this.name, required this.kind, required this.icon, required this.color, this.essential = false});

  final int id;
  final String name;
  final String kind;
  final String icon;
  final String color;
  final bool essential;

  factory Category.fromJson(Json j) => Category(
        id: j['id'],
        name: j['name'],
        kind: j['kind'],
        icon: j['icon'] ?? 'category',
        color: j['color'] ?? '#26A69A',
        essential: j['essential'] ?? false,
      );
}

class Txn {
  Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.accountId,
    required this.accountName,
    this.transferAccountName,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.memberId,
    this.memberName,
    this.memberColor,
    this.installmentTotal,
  });

  final int id;
  final String type;
  final double amount;
  final String description;
  final String date;
  final int accountId;
  final String accountName;
  final String? transferAccountName;
  final int? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final int? memberId;
  final String? memberName;
  final String? memberColor;
  final int? installmentTotal;

  factory Txn.fromJson(Json j) => Txn(
        id: j['id'],
        type: j['type'],
        amount: toDouble(j['amount']),
        description: j['description'] ?? '',
        date: j['date'],
        accountId: j['account_id'],
        accountName: j['account_name'] ?? '',
        transferAccountName: j['transfer_account_name'],
        categoryId: j['category_id'],
        categoryName: j['category_name'],
        categoryIcon: j['category_icon'],
        categoryColor: j['category_color'],
        memberId: j['member_id'],
        memberName: j['member_name'],
        memberColor: j['member_color'],
        installmentTotal: j['installment_total'],
      );
}

class Investment {
  Investment({
    required this.id,
    required this.name,
    required this.type,
    required this.invested,
    required this.current,
    required this.liquidity,
    this.institution,
    this.memberId,
  });

  final int id;
  final String name;
  final String type;
  final double invested;
  final double current;
  final String liquidity;
  final String? institution;
  final int? memberId;

  double get profit => current - invested;
  double get returnRate => invested > 0 ? profit / invested : 0;

  static const types = {
    'fixed_income': 'Renda fixa',
    'treasury': 'Tesouro Direto',
    'stocks': 'Ações',
    'reits': 'Fundos imobiliários',
    'funds': 'Fundos',
    'crypto': 'Cripto',
    'pension': 'Previdência',
    'other': 'Outros',
  };

  static const liquidities = {
    'daily': 'Liquidez diária',
    'monthly': 'Liquidez mensal',
    'maturity': 'No vencimento',
  };

  factory Investment.fromJson(Json j) => Investment(
        id: j['id'],
        name: j['name'],
        type: j['type'],
        invested: toDouble(j['invested_amount']),
        current: toDouble(j['current_value']),
        liquidity: j['liquidity'],
        institution: j['institution'],
        memberId: j['member_id'],
      );
}

class Goal {
  Goal({required this.id, required this.name, required this.target, required this.current, required this.color, this.deadline});

  final int id;
  final String name;
  final double target;
  final double current;
  final String color;
  final String? deadline;

  double get progress => target > 0 ? (current / target).clamp(0, 1).toDouble() : 0;

  factory Goal.fromJson(Json j) => Goal(
        id: j['id'],
        name: j['name'],
        target: toDouble(j['target_amount']),
        current: toDouble(j['current_amount']),
        color: j['color'] ?? '#1E88E5',
        deadline: j['deadline'],
      );
}
