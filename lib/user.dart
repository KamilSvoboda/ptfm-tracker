class User {
  String userName;
  String? password;
  String? familyName;
  String? givenName;
  String? emailAddress;
  String? phoneNumber;
  String? organization;
  List<String>? roles;

  User(
      {required this.userName,
      this.password,
      this.familyName,
      this.givenName,
      this.emailAddress,
      this.phoneNumber,
      this.organization,
      this.roles});

  Map<String, dynamic> toJson() => {'userName': userName, 'password': password};

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userName: json['userName'] as String,
      password: json['password'] != null ? json['password'] as String : null,
      familyName: json['familyName'] != null ? json['familyName'] as String : null,
      givenName: json['givenName'] != null ? json['givenName'] as String : null,
      emailAddress: json['emailAddress'] != null ? json['emailAddress'] as String : null,
      phoneNumber: json['phoneNumber'] != null ? json['phoneNumber'] as String : null,
      organization: json['organization'] != null ? json['organization'] as String : null,
      roles: json['roles'] != null ? List<String>.from(json['roles']) : null,
    );
  }
}
