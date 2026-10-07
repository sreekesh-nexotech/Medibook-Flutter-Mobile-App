import '../../../../../../core/network/api_client.dart';
import '../../../../../../core/network/endpoints.dart';

/// The persons list endpoint as a request description (§6.1).
///
/// A GET is served through `CachedFetcher`, which needs the [ApiRequest]
/// rather than a performed call, so this data source hands back the request.
/// It spells the path and the query; nothing else.
abstract interface class PersonsReadApi {
  /// `GET /patient/me/persons?page_size=100` — every person on the account.
  ApiRequest listRequest();
}

class HttpPersonsReadApi implements PersonsReadApi {
  const HttpPersonsReadApi();

  @override
  ApiRequest listRequest() => ApiRequest(
    path: Endpoints.persons,
    // One page holds everyone: the cap is 100 and a family is a handful.
    query: Endpoints.page(1, size: 100),
  );
}
