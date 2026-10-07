import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/network_exceptions.dart';
import '../../../../../core/storage/cache/cached_fetcher.dart';
import '../../domain/entities/person_summary.dart';
import '../../domain/repositories/persons_read_repository.dart';
import '../data_sources/remote/persons_read_api.dart';

/// [PersonsReadRepository] over the three-layer cache.
class PersonsReadRepositoryImpl implements PersonsReadRepository {
  const PersonsReadRepositoryImpl({
    required PersonsReadApi api,
    required CachedFetcher fetcher,
  }) : _api = api,
       _fetcher = fetcher;

  final PersonsReadApi _api;
  final CachedFetcher _fetcher;

  @override
  Future<List<PersonSummary>> persons({bool forceRefresh = false}) async {
    try {
      final page = await _fetcher.get<Page<PersonSummary>>(
        _api.listRequest(),
        (json) => Page.parse(json, PersonSummaryMapper.fromJson),
        forceRefresh: forceRefresh,
      );
      final items = [...page.results]
        ..sort((a, b) {
          if (a.isSelf != b.isSelf) return a.isSelf ? -1 : 1;
          return a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
        });
      return items;
    } catch (error, stackTrace) {
      throw NetworkExceptions.toFailure(error, stackTrace);
    }
  }
}

/// Wire → entity. The only place the person field names are spelled.
abstract final class PersonSummaryMapper {
  PersonSummaryMapper._();

  static PersonSummary fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final firstName = json['first_name'];
    if (id is! String || id.isEmpty || firstName is! String) {
      throw const ResponseFormatException(
        message: 'person is missing id / first_name',
      );
    }
    final relation = json['relation'];
    final dob = json['date_of_birth'];
    return PersonSummary(
      id: id,
      firstName: firstName,
      lastName: json['last_name'] as String?,
      relation: relation is String ? relation : 'other',
      isSelf: json['is_self'] == true,
      dateOfBirth: dob is String ? DateTime.tryParse(dob) : null,
      gender: json['gender'] as String?,
    );
  }
}
