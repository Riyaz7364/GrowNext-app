import 'package:equatable/equatable.dart';
import 'subscription.dart';
import 'preference.dart';
import 'country.dart';

class UserModel extends Equatable {
  final String? photoUrl;
  final Subscription? subscription;
  final String? email;
  final String? id;
  final String? name;
  final bool? superAdmin;
  final bool? verifyStatus;
  final Preference? preference;
  final String? phoneSecondary;
  final String? phonePrimary;
  final Country? country;

  const UserModel({
    this.photoUrl,
    this.subscription,
    this.email,
    this.id,
    this.name,
    this.superAdmin,
    this.verifyStatus,
    this.preference,
    this.phoneSecondary,
    this.phonePrimary,
    this.country,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      photoUrl: json['photo_url'],
      subscription: json['subscription'] != null
          ? Subscription.fromJson(json['subscription'])
          : null,
      email: json['email'],
      id: json['id'],
      name: json['name'],
      superAdmin: json['super_admin'],
      verifyStatus: json['verify_status'],
      preference: json['preference'] != null
          ? Preference.fromJson(json['preference'])
          : null,
      phoneSecondary: json['phone_secondary'],
      phonePrimary: json['phone_primary'],
      country: json['country'] != null
          ? Country.fromJson(json['country'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'photo_url': photoUrl,
    'subscription': subscription?.toJson(),
    'email': email,
    'id': id,
    'name': name,
    'super_admin': superAdmin,
    'verify_status': verifyStatus,
    'preference': preference?.toJson(),
    'phone_secondary': phoneSecondary,
    'phone_primary': phonePrimary,
    'country': country?.toJson(),
  };

  UserModel copyWith({
    String? photoUrl,
    Subscription? subscription,
    String? email,
    String? id,
    String? name,
    bool? superAdmin,
    bool? verifyStatus,
    Preference? preference,
    String? phoneSecondary,
    String? phonePrimary,
    Country? country,
  }) {
    return UserModel(
      photoUrl: photoUrl ?? this.photoUrl,
      subscription: subscription ?? this.subscription,
      email: email ?? this.email,
      id: id ?? this.id,
      name: name ?? this.name,
      superAdmin: superAdmin ?? this.superAdmin,
      verifyStatus: verifyStatus ?? this.verifyStatus,
      preference: preference ?? this.preference,
      phoneSecondary: phoneSecondary ?? this.phoneSecondary,
      phonePrimary: phonePrimary ?? this.phonePrimary,
      country: country ?? this.country,
    );
  }

  factory UserModel.empty() => const UserModel();

  @override
  List<Object?> get props => [
    photoUrl,
    subscription,
    email,
    id,
    name,
    superAdmin,
    verifyStatus,
    preference,
    phoneSecondary,
    phonePrimary,
    country,
  ];
}
