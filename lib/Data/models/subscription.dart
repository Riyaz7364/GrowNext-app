import 'package:equatable/equatable.dart';

class Subscription extends Equatable {
  final String? subscriptionPlan;

  const Subscription({this.subscriptionPlan});

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(subscriptionPlan: json['subscription_plan']);
  }

  Map<String, dynamic> toJson() => {'subscription_plan': subscriptionPlan};

  Subscription copyWith({String? subscriptionPlan}) {
    return Subscription(
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
    );
  }

  @override
  List<Object?> get props => [subscriptionPlan];
}
