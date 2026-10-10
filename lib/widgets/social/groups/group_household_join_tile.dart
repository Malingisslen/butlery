// BUT-2267: a member of a group the owner has marked as household joins the
// household from the group page, so they can then share their own allergens
// with it. Joining is their own act; the owner decides who may, through who is
// in the group. Joining shares nothing: the consent lives behind
// its own dialog (DPIA Annex A), which the joined state points to.

import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// "Gå med i hushållet" for a non-owner member of a household-marked [group],
/// or "Du är med i hushållet" once they have. Hidden for everyone else, and
/// while the answer is not known.
class GroupHouseholdJoinTile extends StatefulWidget {
  const GroupHouseholdJoinTile({super.key, required this.group});

  final FriendCategory group;

  @override
  State<GroupHouseholdJoinTile> createState() => _GroupHouseholdJoinTileState();
}

class _GroupHouseholdJoinTileState extends State<GroupHouseholdJoinTile> {
  /// Null until the household read answers; the tile stays hidden meanwhile,
  /// and after a failed read, rather than offer a join to someone who is in.
  bool? _joined;
  bool _busy = false;

  /// Read once in [initState]: services are resolved there, never in `build`.
  late final bool _enabled;
  late final String? _userId;
  late final HouseholdRepository? _households;

  bool get _eligible {
    final uid = _userId;
    final group = widget.group;
    return _enabled &&
        uid != null &&
        group.isHousehold &&
        uid != group.ownerId &&
        group.friendUserIds.contains(uid);
  }

  @override
  void initState() {
    super.initState();
    _enabled =
        ServiceLocator.tryGet<FeatureFlagService>()?.isEnabled(
          FeatureFlags.enableHouseholdAllergenSharing,
        ) ??
        false;
    _userId = ServiceLocator.tryGet<PermissionService>()?.currentUserId;
    _households = ServiceLocator.tryGet<HouseholdRepository>();
    _resolve();
  }

  @override
  void didUpdateWidget(GroupHouseholdJoinTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.group;
    final after = widget.group;
    if (before.id != after.id ||
        before.isHousehold != after.isHousehold ||
        before.friendUserIds.length != after.friendUserIds.length) {
      _joined = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (!_eligible) return;
    final repo = _households;
    final uid = _userId;
    if (repo == null || uid == null) return;
    try {
      final group = widget.group;
      final joined = (await repo.getForUser(uid)).any(
        (h) =>
            h.isLinkedToGroup &&
            h.sourceGroupId == group.id &&
            h.sourceGroupOwnerId == group.ownerId,
      );
      if (mounted) setState(() => _joined = joined);
    } catch (e) {
      AppLogger.warning('Could not read household membership: $e');
    }
  }

  Future<void> _join() async {
    final l10n = context.l10n;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: l10n.householdJoinTitle,
      message: l10n.householdJoinConfirmBody,
      titleIcon: ButleryIcons.house,
      primaryActionText: l10n.householdJoinAction,
      secondaryActionText: l10n.commonCancel,
    );
    if (confirmed != true || !mounted) return;
    final repo = _households;
    if (repo == null) return;

    setState(() => _busy = true);
    try {
      await repo.joinGroupHousehold(
        ownerId: widget.group.ownerId,
        groupId: widget.group.id,
      );
      if (mounted) setState(() => _joined = true);
    } catch (e) {
      AppLogger.warning('Could not join the household: $e');
      if (mounted) {
        SnackBarUtils.showFailure(context, what: l10n.householdJoinFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final joined = _joined;
    if (joined == null || !_eligible) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spacingL),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ButleryIcon(
          ButleryIcons.house,
          color: joined ? cs.onSurface : cs.onSurfaceVariant,
          size: AppDimensions.iconSizeL,
        ),
        title: Text(
          joined ? l10n.householdJoinedTitle : l10n.householdJoinTitle,
          style: AppTextStyles.titleMedium,
        ),
        subtitle: Text(
          joined ? l10n.householdJoinedSubtitle : l10n.householdJoinSubtitle,
          style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: joined
            ? TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, Routes.settingsFamily),
                child: Text(l10n.householdOpenSettings),
              )
            : TextButton(
                onPressed: _busy ? null : _join,
                child: Text(l10n.householdJoinAction),
              ),
      ),
    );
  }
}
