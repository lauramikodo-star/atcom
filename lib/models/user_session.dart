class UserSession {
  final String token;
  final UserData user;
  final DateTime expiresAt;

  UserSession({
    required this.token,
    required this.user,
    required this.expiresAt,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      token: json['token'],
      user: UserData.fromJson(json['user']),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expires']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user.toJson(),
      'expires': expiresAt.millisecondsSinceEpoch,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class UserData {
  final String id;
  final String email;
  final String nom;
  final String prenom;
  final String nd;
  final String type;

  UserData({
    required this.id,
    required this.email,
    required this.nom,
    required this.prenom,
    required this.nd,
    required this.type,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      nd: json['nd'] ?? '',
      type: json['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nom': nom,
      'prenom': prenom,
      'nd': nd,
      'type': type,
    };
  }

  String get fullName => '$prenom $nom';
}

class AccountDetails {
  final String prenom;
  final String nom;
  final String nd;
  final String mobile;
  final String email;
  final String adresse;
  final String offre;
  final String type1;
  final String status;
  final double balance;
  final double dette;
  final double credit;
  final String dateexp;
  final String ncli;
  final String? bonusVoixRestant;

  AccountDetails({
    required this.prenom,
    required this.nom,
    required this.nd,
    required this.mobile,
    required this.email,
    required this.adresse,
    required this.offre,
    required this.type1,
    required this.status,
    required this.balance,
    required this.dette,
    required this.credit,
    required this.dateexp,
    required this.ncli,
    this.bonusVoixRestant,
  });

  factory AccountDetails.fromJson(Map<String, dynamic> json) {
    return AccountDetails(
      prenom: json['prenom'] ?? '',
      nom: json['nom'] ?? '',
      nd: json['nd'] ?? '',
      mobile: json['mobile'] ?? '',
      email: json['email'] ?? '',
      adresse: json['adresse'] ?? '',
      offre: json['offre'] ?? '',
      type1: json['type1'] ?? '',
      status: json['status'] ?? '',
      balance: _parseDouble(json['balance']),
      dette: _parseDouble(json['dette']),
      credit: _parseDouble(json['credit']),
      dateexp: json['dateexp'] ?? '',
      ncli: json['ncli'] ?? '',
      bonusVoixRestant: json['bonus_voix_restant'],
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  bool get hasDebt => dette > 0;
  bool get isExpired {
    try {
      final expiryDate = DateTime.parse(dateexp);
      return expiryDate.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }
}

class ServiceInfo {
  final bool found;
  final String type;
  final String ncli;
  final String offer;

  ServiceInfo({
    required this.found,
    required this.type,
    required this.ncli,
    required this.offer,
  });

  factory ServiceInfo.fromJson(Map<String, dynamic> json) {
    return ServiceInfo(
      found: json['found'] ?? false,
      type: json['type'] ?? '',
      ncli: json['ncli'] ?? '',
      offer: json['offer'] ?? 'Standard',
    );
  }
}

class RechargeResult {
  final bool success;
  final String message;
  final Map<String, dynamic> response;

  RechargeResult({
    required this.success,
    required this.message,
    required this.response,
  });
}