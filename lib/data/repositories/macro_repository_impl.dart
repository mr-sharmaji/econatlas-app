import '../../domain/repositories/macro_repository.dart';
import '../datasources/remote_data_source.dart';
import '../models/macro_indicator.dart';

class MacroRepositoryImpl implements MacroRepository {
  final RemoteDataSource _remote;

  MacroRepositoryImpl(this._remote);

  @override
  Future<MacroResponse> getMacroIndicators({
    String? country,
    int limit = 50,
    int offset = 0,
    bool latestOnly = false,
  }) {
    return _remote.getMacroIndicators(
      country: country,
      limit: limit,
      offset: offset,
      latestOnly: latestOnly,
    );
  }
}
