import 'dart:async';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/core/network/api_paths.dart';
import 'package:smartcard_flutter/core/network/connectivity_service.dart';
import 'package:smartcard_flutter/core/services/dio_client.dart';
import 'package:smartcard_flutter/core/database/sqlite_database.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/domain/repositories/scanner_repository.dart';

class ScannerRepositoryImpl implements IScannerRepository {
  final ConnectivityService connectivity;
  final _controller = StreamController<List<ScannedContactModel>>.broadcast();
  final DioClient _client = DioClient();

  ScannerRepositoryImpl({required this.connectivity});

  @override
  Stream<List<ScannedContactModel>> get scannedContactsStream => _controller.stream;

  @override
  Future<ScannedContactModel> fetchAndCacheScannedContact(String qrValue) async {
    final payload = {'qr_value': qrValue};
    final response = await _client.dio.post(ApiPaths.qrPreview, data: payload);
    final raw = response.data['data'] ?? response.data;
    final contact = ScannedContactModel.fromJson(Map<String, dynamic>.from(raw as Map));

    await SqliteDatabase.saveContact(contact.copyWith(syncStatus: 'pending'));
    await _emitLocalContacts();
    return contact;
  }

  @override
  Future<List<ScannedContactModel>> getAllLocalScannedContacts() async {
    final local = await SqliteDatabase.getAllContactsAsync();
    await _emitLocalContacts();
    return local;
  }

  Future<void> _emitLocalContacts() async {
    final current = await SqliteDatabase.getAllContactsAsync();
    _controller.add(current);
  }
}
