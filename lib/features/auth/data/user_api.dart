import '../../../core/network/api_client.dart';
import '../domain/user.dart';

class UserApi {
  UserApi(this._client);
  final ApiClient _client;

  Future<AppUser> me() async {
    final response = await _client.dio.get<Map<String, dynamic>>('/users/me');
    return AppUser.fromJson(response.data!);
  }
}
