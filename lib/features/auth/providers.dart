
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/dio_client.dart';
import 'data/auth_remote.dart';
import 'data/auth_repository_impl.dart';
import 'domain/auth_repository.dart';

final dioProvider = Provider((_) => DioClient.create());
final authRepoProvider = Provider<AuthRepository>((ref) {
  final dio = ref.read(dioProvider);
  return AuthRepositoryImpl(AuthRemote(dio));
});
final sessionValidProvider = FutureProvider<bool>((ref) async {
  final repo = ref.read(authRepoProvider);
  return repo.isValidSession();
});
