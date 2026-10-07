import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';

/// `GET /patient/search?q=` as a typed remote data source. HTTP only.
abstract interface class SearchApi {
  Future<Map<String, Object?>> search(String query);
}

class HttpSearchApi implements SearchApi {
  const HttpSearchApi(this._client);

  final ApiClient _client;

  @override
  Future<Map<String, Object?>> search(String query) async {
    final response = await _client.get(
      Endpoints.search,
      query: {'q': query},
      requiresAuth: false,
    );
    return response.requireMap;
  }
}
