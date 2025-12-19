import 'dart:io';

import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'local_cache_service.dart';

class ExportService {
  final LocalCacheService _cacheService;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  ExportService({LocalCacheService? cacheService})
      : _cacheService = cacheService ?? LocalCacheService();

  /// Exports cached observations and conditions to a PDF file.
  /// Returns the saved file path.
  Future<String> exportToPdf({String? userName, String? userEmail}) async {
    final observations = await _cacheService.getCachedObservations();
    final conditions = await _cacheService.getCachedConditions();

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            _buildHeader(userName: userName, userEmail: userEmail),
            pw.SizedBox(height: 16),
            _buildObservations(observations),
            pw.SizedBox(height: 24),
            _buildConditions(conditions),
          ];
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/phr_export_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await doc.save());

    // Optional: attempt to open
    await OpenFilex.open(file.path);

    return file.path;
  }

  pw.Widget _buildHeader({String? userName, String? userEmail}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Personal Health Record Export', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Generated: ${_dateFormat.format(DateTime.now())}', style: pw.TextStyle(fontSize: 10)),
        if (userName != null) pw.Text('Name: $userName', style: pw.TextStyle(fontSize: 12)),
        if (userEmail != null) pw.Text('Email: $userEmail', style: pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildObservations(List<Map<String, dynamic>> observations) {
    if (observations.isEmpty) {
      return pw.Text('No observations available.', style: pw.TextStyle(fontSize: 12));
    }

    final headers = ['Type', 'Value', 'Unit', 'Timestamp'];
    final data = observations.map((o) {
      final type = o['type']?.toString() ?? '-';
      final value = o['value']?.toString() ?? '-';
      final unit = o['unit']?.toString() ?? '-';
      final ts = _formatTimestamp(o['effectiveDateTime']);
      return [type, value, unit, ts];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Vital Signs', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: pw.TextStyle(fontSize: 10),
          cellAlignment: pw.Alignment.centerLeft,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          border: pw.TableBorder.all(width: 0.2),
        ),
      ],
    );
  }

  pw.Widget _buildConditions(List<Map<String, dynamic>> conditions) {
    if (conditions.isEmpty) {
      return pw.Text('No conditions available.', style: pw.TextStyle(fontSize: 12));
    }

    final headers = ['Category', 'Severity', 'Description', 'Timestamp'];
    final data = conditions.map((c) {
      print(c);
      final cat = c['condition']?.toString() ?? '-';
      final sev = c['severity']?.toString() ?? '-';
      final desc = c['description']?.toString() ?? '-';
      final ts = _formatTimestamp(c['onsetDateTime']);
      return [cat, sev, desc, ts];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Conditions', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: pw.TextStyle(fontSize: 10),
          cellAlignment: pw.Alignment.centerLeft,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          border: pw.TableBorder.all(width: 0.2),
        ),
      ],
    );
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) return '-';

    try {
      if (value is int) {
        // Heuristically assume ms if longer than 10 digits
        final isMs = value > 10000000000;
        final dt = DateTime.fromMillisecondsSinceEpoch(isMs ? value : value * 1000, isUtc: true).toLocal();
        return _dateFormat.format(dt);
      }

      if (value is double) {
        final asInt = value.toInt();
        final isMs = asInt > 10000000000;
        final dt = DateTime.fromMillisecondsSinceEpoch(isMs ? asInt : asInt * 1000, isUtc: true).toLocal();
        return _dateFormat.format(dt);
      }

      // ISO string fallback
      final raw = value.toString();
      final dt = DateTime.parse(raw).toLocal();
      return _dateFormat.format(dt);
    } catch (_) {
      return value.toString();
    }
  }
}
