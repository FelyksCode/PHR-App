enum BackendSyncStatusType { queued, running, success, failed, unknown }

class BackendSyncStatus {
  final BackendSyncStatusType status;
  final String? message;
  final String? jobId;

  const BackendSyncStatus({required this.status, this.message, this.jobId});

  bool get isTerminal =>
      status == BackendSyncStatusType.success ||
      status == BackendSyncStatusType.failed;

  factory BackendSyncStatus.fromJson(Map<String, dynamic> json) {
    final raw =
        (json['last_job_status'] ??
                json['status'] ??
                json['state'] ??
                json['sync_status'])
            ?.toString()
            .toLowerCase();

    BackendSyncStatusType status;
    switch (raw) {
      case 'pending':
      case 'queued':
      case 'accepted':
        status = BackendSyncStatusType.queued;
        break;
      case 'running':
      case 'in_progress':
      case 'processing':
      case 'syncing':
        status = BackendSyncStatusType.running;
        break;
      case 'success':
      case 'succeeded':
      case 'done':
      case 'completed':
        status = BackendSyncStatusType.success;
        break;
      case 'failed':
      case 'error':
        status = BackendSyncStatusType.failed;
        break;
      default:
        status = BackendSyncStatusType.unknown;
    }

    return BackendSyncStatus(
      status: status,
      message:
          json['message']?.toString() ??
          json['error']?.toString() ??
          json['last_job_error']?.toString(),
      jobId:
          json['sync_job_id']?.toString() ??
          json['job_id']?.toString() ??
          json['id']?.toString(),
    );
  }
}
