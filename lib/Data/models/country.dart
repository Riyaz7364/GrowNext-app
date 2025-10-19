import 'package:equatable/equatable.dart';

class Country extends Equatable {
  final String? name;
  final String? currencyCode;

  const Country({this.name, this.currencyCode});

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(name: json['name'], currencyCode: json['currency_code']);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'currency_code': currencyCode,
  };

  Country copyWith({String? name, String? currencyCode}) {
    return Country(
      name: name ?? this.name,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }

  @override
  List<Object?> get props => [name, currencyCode];
}
