import 'package:image_picker/image_picker.dart';

import '../datasources/remote/supabase_freebies_datasource.dart';

abstract class FreebiesRepository {
  Future<List<Map<String, dynamic>>> fetchDonations({
    String? city,
    String status,
  });

  Future<Map<String, dynamic>?> fetchDonationById(String id);

  Future<List<Map<String, dynamic>>> fetchNearbyDonations({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? city,
    String status,
  });

  Future<void> submitDonationRequest({
    required String donationId,
    required String name,
    required String phone,
    required String city,
    required String area,
    required String reason,
    required String contactMethod,
  });

  Future<void> confirmDonationDelivered({
    required String donationId,
    required String actorPhone,
  });

  Future<bool> canConfirmDonationDelivery({
    required String donationId,
    required String actorPhone,
  });

  Future<void> submitDonationReport({
    required String donationId,
    required String reason,
    String? details,
    String? reporterName,
    String? reporterPhone,
  });

  Future<void> submitDonation({
    required String donorName,
    required String donorPhone,
    required String city,
    required String area,
    required String title,
    required String description,
    required List<XFile> images,
    double? latitude,
    double? longitude,
  });
}

class SupabaseFreebiesRepository implements FreebiesRepository {
  SupabaseFreebiesRepository({SupabaseFreebiesDataSource? dataSource})
      : _dataSource = dataSource ?? SupabaseFreebiesDataSource();

  final SupabaseFreebiesDataSource _dataSource;

  @override
  Future<List<Map<String, dynamic>>> fetchDonations({
    String? city,
    String status = 'available',
  }) {
    return _dataSource.fetchDonations(city: city, status: status);
  }

  @override
  Future<Map<String, dynamic>?> fetchDonationById(String id) {
    return _dataSource.fetchDonationById(id);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchNearbyDonations({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? city,
    String status = 'available',
  }) {
    return _dataSource.fetchNearbyDonations(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      city: city,
      status: status,
    );
  }

  @override
  Future<void> submitDonationRequest({
    required String donationId,
    required String name,
    required String phone,
    required String city,
    required String area,
    required String reason,
    required String contactMethod,
  }) {
    return _dataSource.submitDonationRequest(
      donationId: donationId,
      name: name,
      phone: phone,
      city: city,
      area: area,
      reason: reason,
      contactMethod: contactMethod,
    );
  }

  @override
  Future<void> confirmDonationDelivered({
    required String donationId,
    required String actorPhone,
  }) {
    return _dataSource.confirmDonationDelivered(
      donationId: donationId,
      actorPhone: actorPhone,
    );
  }

  @override
  Future<bool> canConfirmDonationDelivery({
    required String donationId,
    required String actorPhone,
  }) {
    return _dataSource.canConfirmDonationDelivery(
      donationId: donationId,
      actorPhone: actorPhone,
    );
  }

  @override
  Future<void> submitDonationReport({
    required String donationId,
    required String reason,
    String? details,
    String? reporterName,
    String? reporterPhone,
  }) {
    return _dataSource.submitDonationReport(
      donationId: donationId,
      reason: reason,
      details: details,
      reporterName: reporterName,
      reporterPhone: reporterPhone,
    );
  }

  @override
  Future<void> submitDonation({
    required String donorName,
    required String donorPhone,
    required String city,
    required String area,
    required String title,
    required String description,
    required List<XFile> images,
    double? latitude,
    double? longitude,
  }) {
    return _dataSource.submitDonation(
      donorName: donorName,
      donorPhone: donorPhone,
      city: city,
      area: area,
      title: title,
      description: description,
      images: images,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
