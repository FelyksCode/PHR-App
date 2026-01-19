class HealthObservation {
  final String id;
  final String display;
  final double? value;
  final String? unit;
  final DateTime? effectiveDateTime;
  final String? type;

  const HealthObservation({
    required this.id,
    required this.display,
    this.value,
    this.unit,
    this.effectiveDateTime,
    this.type,
  });

  factory HealthObservation.fromJson(Map<String, dynamic> json) {
    final rawValue = json['value'];
    double? parsedValue;
    if (rawValue is num) {
      parsedValue = rawValue.toDouble();
    } else if (rawValue is String) {
      parsedValue = double.tryParse(rawValue);
    }

    final rawDate =
        json['effectiveDateTime'] ?? json['timestamp'] ?? json['date'];
    DateTime? parsedDate;
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate);
    }

    return HealthObservation(
      id: json['id']?.toString() ?? '',
      display:
          json['display']?.toString() ?? json['type']?.toString() ?? 'Unknown',
      value: parsedValue,
      unit: json['unit']?.toString(),
      effectiveDateTime: parsedDate,
      type: json['type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display': display,
      'value': value,
      'unit': unit,
      'effectiveDateTime': effectiveDateTime?.toIso8601String(),
      'type': type,
    };
  }
}

class FitbitStatus {
  final bool connected;
  final DateTime? expiresAt;
  final String? message;
  final String? vendor;
  final bool tokenExpiringSoon;
  final Map<String, dynamic>? raw;

  const FitbitStatus({
    required this.connected,
    this.expiresAt,
    this.message,
    this.vendor,
    this.tokenExpiringSoon = false,
    this.raw,
  });

  factory FitbitStatus.fromJson(Map<String, dynamic> json) {
    final rawExpires = json['expires_at'] ?? json['expiresAt'];
    DateTime? expiresAt;
    if (rawExpires is String) {
      expiresAt = DateTime.tryParse(rawExpires);
    }

    final connected = json['connected'] == true || json['is_connected'] == true;
    final expiringSoon =
        json['expiring'] == true || json['token_expiring'] == true;

    return FitbitStatus(
      connected: connected,
      expiresAt: expiresAt,
      message: json['message']?.toString(),
      vendor: json['vendor']?.toString(),
      tokenExpiringSoon: expiringSoon,
      raw: json,
    );
  }

  bool get isConnected => connected;

  bool get isExpiringSoon {
    if (tokenExpiringSoon) return true;
    if (expiresAt == null) return false;
    final now = DateTime.now();
    return expiresAt!.isBefore(now.add(const Duration(hours: 24)));
  }
}

class SyncResult {
  final String status;
  final String? message;
  final int createdCount;
  final int updatedCount;
  final int failedCount;

  const SyncResult({
    required this.status,
    this.message,
    this.createdCount = 0,
    this.updatedCount = 0,
    this.failedCount = 0,
  });

  factory SyncResult.fromJson(Map<String, dynamic> json) {
    return SyncResult(
      status: json['status']?.toString() ?? 'unknown',
      message: json['message']?.toString(),
      createdCount: json['created'] is int
          ? json['created'] as int
          : int.tryParse(json['created']?.toString() ?? '') ?? 0,
      updatedCount: json['updated'] is int
          ? json['updated'] as int
          : int.tryParse(json['updated']?.toString() ?? '') ?? 0,
      failedCount: json['failed'] is int
          ? json['failed'] as int
          : int.tryParse(json['failed']?.toString() ?? '') ?? 0,
    );
  }
}

class PaginatedHealthObservations {
  final List<HealthObservation> items;
  final int page;
  final int pageSize;
  final int? total;

  const PaginatedHealthObservations({
    required this.items,
    required this.page,
    required this.pageSize,
    this.total,
  });

  bool get hasMore {
    if (total == null) {
      return items.length == pageSize;
    }
    return page * pageSize < total!;
  }
}
