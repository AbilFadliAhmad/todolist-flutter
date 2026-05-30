import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

class ExportHelper {
  // --- 1. EXPORT KE CSV (Untuk Google Sheets / Excel) ---
  static Future<void> exportToCSV(List<Task> tasks) async {
    List<List<dynamic>> rows = [];

    // Membuat Header Tabel
    rows.add(["ID", "Nama Tugas", "Status", "Waktu Pembuatan"]);

    // Memasukkan data dari SQLite ke dalam baris tabel
    for (var task in tasks) {
      final status = task.isDone == 1 ? "Selesai" : "Proses";
      final date = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(task.createdAt));
      rows.add([task.id, task.title, status, date]);
    }

    // Konversi array ke format string CSV
    String csvData = csv.encode(rows);
    // Simpan file ke memori internal (sementara)
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/laporan_tugas.csv');
    await file.writeAsString(csvData);

    // Buka menu "Bagikan" bawaan HP
    await Share.shareXFiles([XFile(file.path)], text: 'Laporan Tugas (CSV)');
  }

  // --- 2. EXPORT KE PDF ---
  static Future<void> exportToPDF(List<Task> tasks) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Laporan Modern Task", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              // Membuat Tabel PDF
              pw.Table.fromTextArray(
                headers: ["Nama Tugas", "Status", "Tanggal"],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                data: tasks.map((task) {
                  final status = task.isDone == 1 ? "Selesai" : "Proses";
                  final date = DateFormat('dd MMM yyyy').format(DateTime.parse(task.createdAt));
                  return [task.title, status, date];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    // Simpan file ke memori internal (sementara)
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/laporan_tugas.pdf');
    await file.writeAsBytes(await pdf.save());

    // Buka menu "Bagikan" bawaan HP
    await Share.shareXFiles([XFile(file.path)], text: 'Laporan Tugas (PDF)');
  }
}