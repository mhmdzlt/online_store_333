import '../datasources/remote/supabase_admin_datasource.dart';

abstract class AdminRepository {
  Stream<List<Map<String, dynamic>>> streamUserEvents({int limit});
  Future<List<Map<String, dynamic>>> listSellerProductControls();
  Future<Map<String, dynamic>> setSellerProductControl({
    required String sellerId,
    required bool canAddProducts,
    required String approvalMode,
    required bool isBlocked,
    String? notes,
  });
  Future<List<Map<String, dynamic>>> listPendingProducts({
    int limit,
    int offset,
  });
  Future<Map<String, dynamic>> reviewProduct({
    required String productId,
    required bool approve,
    String? note,
  });
}

class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository({SupabaseAdminDataSource? dataSource})
      : _dataSource = dataSource ?? SupabaseAdminDataSource();

  final SupabaseAdminDataSource _dataSource;

  @override
  Stream<List<Map<String, dynamic>>> streamUserEvents({int limit = 50}) {
    return _dataSource.streamUserEvents(limit: limit);
  }

  @override
  Future<List<Map<String, dynamic>>> listSellerProductControls() {
    return _dataSource.listSellerProductControls();
  }

  @override
  Future<Map<String, dynamic>> setSellerProductControl({
    required String sellerId,
    required bool canAddProducts,
    required String approvalMode,
    required bool isBlocked,
    String? notes,
  }) {
    return _dataSource.setSellerProductControl(
      sellerId: sellerId,
      canAddProducts: canAddProducts,
      approvalMode: approvalMode,
      isBlocked: isBlocked,
      notes: notes,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listPendingProducts({
    int limit = 100,
    int offset = 0,
  }) {
    return _dataSource.listPendingProducts(limit: limit, offset: offset);
  }

  @override
  Future<Map<String, dynamic>> reviewProduct({
    required String productId,
    required bool approve,
    String? note,
  }) {
    return _dataSource.reviewProduct(
      productId: productId,
      approve: approve,
      note: note,
    );
  }
}
