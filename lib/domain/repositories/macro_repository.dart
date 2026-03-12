import '../../data/models/macro_indicator.dart';

abstract class MacroRepository {
  Future<MacroResponse> getMacroIndicators({
    String? country,
    int limit = 50,
    int offset = 0,
    bool latestOnly = false,
  });
}
