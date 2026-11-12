import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';

/// What came of a freeze, extension or release of a saved copy.
sealed class FreezeResult {
  const FreezeResult();
}

class FreezeSucceeded extends FreezeResult {
  const FreezeSucceeded(this.outcome);
  final FreezeOutcome outcome;
}

class FreezeBlocked extends FreezeResult {
  const FreezeBlocked(this.block);
  final FreezeBlock block;
}

class FreezeFailed extends FreezeResult {
  const FreezeFailed();
}

Future<FreezeResult> runFreeze(
  ModerationAppealsService service,
  String reportId, {
  required FreezeAction action,
  FreezeReason? reason,
}) async {
  try {
    return FreezeSucceeded(
      await service.freezeEvidence(reportId, action: action, reason: reason),
    );
  } on FreezeEvidenceException catch (e) {
    final block = e.block;
    if (block != null) return FreezeBlocked(block);
    AppLogger.error('Freeze evidence failed', e);
    return const FreezeFailed();
  } catch (e) {
    AppLogger.error('Freeze evidence failed', e);
    return const FreezeFailed();
  }
}
