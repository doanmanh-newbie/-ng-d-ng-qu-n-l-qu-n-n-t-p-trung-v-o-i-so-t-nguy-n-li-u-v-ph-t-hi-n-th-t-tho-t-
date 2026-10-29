import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/shift/domain/shift_models.dart';
import 'package:fore/features/shift/domain/shift_repository.dart';

/// Bản giả của [ShiftRepository] cho test: không cần mạng, không cần Supabase.
class FakeShiftRepository implements ShiftRepository {
  CurrentShift? shift;

  /// Lỗi cho mọi lệnh gọi (ví dụ mất mạng).
  AppFailure? failure;

  /// Mô phỏng người khác mở ca ngay trước khi mình bấm.
  bool someoneOpensFirst = false;

  final openedWith = <int>[];

  @override
  Future<CurrentShift?> currentShift() async {
    if (failure != null) throw failure!;
    return shift;
  }

  @override
  Future<void> openShift({required int openingCash}) async {
    if (failure != null) throw failure!;
    if (someoneOpensFirst || shift != null) {
      shift ??= CurrentShift(
        id: 's1',
        openedByName: 'An',
        openedAt: DateTime(2026, 10, 25, 8, 2),
      );
      throw const ShiftAlreadyOpenFailure();
    }
    openedWith.add(openingCash);
    shift = CurrentShift(
      id: 's1',
      openedByName: 'Mình',
      openedAt: DateTime(2026, 10, 25, 8, 0),
      openedByMe: true,
    );
  }
}
