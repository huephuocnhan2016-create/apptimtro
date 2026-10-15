import '../domain/call_session.dart';
import 'call_api.dart';

class CallRepository {
  CallRepository(this.api);

  final CallApi api;

  Future<CallSession> create(String roomId) => api.create(roomId);
  Future<CallSession> get(String id) => api.get(id);
  Future<CallSession> accept(String id) => api.accept(id);
  Future<void> reject(String id) => api.reject(id);
  Future<void> end(String id) => api.end(id);
  Future<List<CallSession>> history() => api.history();
}
