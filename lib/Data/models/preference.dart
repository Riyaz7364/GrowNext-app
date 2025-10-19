import 'package:equatable/equatable.dart';

class Preference extends Equatable {
  final String? mode;
  final String? toastMessagePosition;
  final String? timeZone;
  final bool? isSidebarOpen;

  const Preference({
    this.mode,
    this.toastMessagePosition,
    this.timeZone,
    this.isSidebarOpen,
  });

  factory Preference.fromJson(Map<String, dynamic> json) {
    return Preference(
      mode: json['mode'],
      toastMessagePosition: json['toast_message_position'],
      timeZone: json['time_zone'],
      isSidebarOpen: json['is_sidebar_open'],
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'toast_message_position': toastMessagePosition,
    'time_zone': timeZone,
    'is_sidebar_open': isSidebarOpen,
  };

  Preference copyWith({
    String? mode,
    String? toastMessagePosition,
    String? timeZone,
    bool? isSidebarOpen,
  }) {
    return Preference(
      mode: mode ?? this.mode,
      toastMessagePosition: toastMessagePosition ?? this.toastMessagePosition,
      timeZone: timeZone ?? this.timeZone,
      isSidebarOpen: isSidebarOpen ?? this.isSidebarOpen,
    );
  }

  @override
  List<Object?> get props => [
    mode,
    toastMessagePosition,
    timeZone,
    isSidebarOpen,
  ];
}
