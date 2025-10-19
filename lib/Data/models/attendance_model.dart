import 'package:equatable/equatable.dart';

class AttendanceModel extends Equatable {
  final String? id;
  final DateTime? startTime;
  final DateTime? endTime;
  final double? duration;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final String? selfieUrl;
  final double? distanceKm;
  final String? note;
  final String source;
  final DateTime? clientCreatedAt;

  const AttendanceModel({
    this.id,
    this.startTime,
    this.endTime,
    this.duration,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.selfieUrl,
    this.distanceKm,
    this.note,
    this.source = "mobile",
    this.clientCreatedAt,
  });

  /// Creates a copy of this model with optional new values.
  AttendanceModel copyWith({
    String? taskId,
    DateTime? startTime,
    DateTime? endTime,
    double? duration,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    String? selfieUrl,
    double? distanceKm,
    String? note,
    String? source,
    DateTime? clientCreatedAt,
  }) {
    return AttendanceModel(
      id: taskId ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      distanceKm: distanceKm ?? this.distanceKm,
      note: note ?? this.note,
      source: source ?? this.source,
      clientCreatedAt: clientCreatedAt ?? this.clientCreatedAt,
    );
  }

  /// Converts a JSON map into an [AttendanceModel].
  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      duration: (json['duration'] as num?)?.toDouble(),
      startLat: (json['startLat'] as num).toDouble(),
      startLng: (json['startLng'] as num).toDouble(),
      endLat: (json['endLat'] as num?)?.toDouble(),
      endLng: (json['endLng'] as num?)?.toDouble(),
      selfieUrl: json['selfieUrl'] as String,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      note: json['note'] as String?,
      source: json['source'] as String,
      clientCreatedAt: DateTime.parse(json['clientCreatedAt']),
    );
  }

  /// Converts this [AttendanceModel] into a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'selfieUrl': selfieUrl,
      'distanceKm': distanceKm,
      'note': note,
      'source': source,
      'clientCreatedAt': clientCreatedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    startTime,
    endTime,
    duration,
    startLat,
    startLng,
    endLat,
    endLng,
    selfieUrl,
    distanceKm,
    note,
    source,
    clientCreatedAt,
  ];

  @override
  String toString() {
    return 'AttendanceModel(id: $id, '
        'startTime: $startTime, endTime: $endTime, duration: $duration, '
        'startLat: $startLat, startLng: $startLng, endLat: $endLat, endLng: $endLng, '
        'selfieUrl: $selfieUrl, distanceKm: $distanceKm, note: $note, '
        'source: $source, clientCreatedAt: $clientCreatedAt)';
  }
}
