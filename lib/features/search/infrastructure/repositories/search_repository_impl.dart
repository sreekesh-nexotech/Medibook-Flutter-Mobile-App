import '../../../../core/network/network_exceptions.dart';
import '../../../booking/infrastructure/repositories/booking_mappers.dart';
import '../../domain/entities/search_results.dart';
import '../../domain/repositories/search_repository.dart';
import '../data_sources/remote/search_api.dart';

/// [SearchRepository] over [SearchApi]. Results are not cached: a search is
/// a one-shot read of a fast public endpoint, and the debounce in the
/// application layer already keeps the call rate down.
class SearchRepositoryImpl implements SearchRepository {
  const SearchRepositoryImpl({required SearchApi api}) : _api = api;

  final SearchApi _api;

  @override
  Future<SearchResults> search(String query) async {
    try {
      final json = await _api.search(query);
      return SearchResults(
        query: BookingMappers.optStr(json, 'q') ?? query,
        hospitals: [
          for (final h in BookingMappers.list(json['hospitals']))
            BookingMappers.hospitalCard(h),
        ],
        departments: [
          for (final d in BookingMappers.list(json['departments']))
            BookingMappers.departmentSummary(d),
        ],
        doctors: [
          for (final d in BookingMappers.list(json['doctors']))
            BookingMappers.doctorCard(d),
        ],
      );
    } catch (error, stack) {
      Error.throwWithStackTrace(
        NetworkExceptions.toFailure(error, stack),
        stack,
      );
    }
  }
}
