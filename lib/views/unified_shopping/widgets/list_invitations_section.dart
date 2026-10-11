import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/services/unified/operations/list_invitation_operations.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/viewmodels/list_invitations_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/list_invitation_card.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/social/block_user_action.dart';

/// Pending shared-list invitations at the top of the shopping tab. Draws
/// nothing when there are none.
class ListInvitationsSection extends StatefulWidget {
  const ListInvitationsSection({
    this.viewModel,
    this.friendsViewModel,
    super.key,
  });

  /// Injected by tests; otherwise resolved from the service locator.
  final ListInvitationsViewModel? viewModel;
  final FriendsViewModel? friendsViewModel;

  @override
  State<ListInvitationsSection> createState() => _ListInvitationsSectionState();
}

class _ListInvitationsSectionState extends State<ListInvitationsSection> {
  ListInvitationsViewModel? _vm;
  FriendsViewModel? _friends;
  bool _ownsVm = false;

  @override
  void initState() {
    super.initState();
    _vm = widget.viewModel;
    if (_vm == null) {
      _vm = ServiceLocator.tryGet<ListInvitationsViewModel>();
      _ownsVm = _vm != null;
    }
  }

  @override
  void dispose() {
    if (_ownsVm) _vm?.dispose();
    if (widget.friendsViewModel == null) _friends?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final invitations = vm.invitations;
        if (invitations.isEmpty) return const SizedBox.shrink();
        // Capped, so a pile of invitations scrolls instead of pushing the
        // list off the screen.
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.4,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingL,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ButleryListSection(
                  title: context.l10n.listInvitationsSection,
                  rows: const [],
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                for (final invitation in invitations)
                  ListInvitationCard(
                    key: ValueKey(invitation.id),
                    invitation: invitation,
                    busy: vm.isResponding(invitation.id),
                    onAccept: () => _accept(vm, invitation),
                    onDecline: () => _decline(vm, invitation),
                    onBlock: () => _block(vm, invitation),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _accept(
    ListInvitationsViewModel vm,
    SocialRequest invitation,
  ) async {
    final outcome = await vm.accept(invitation.id);
    if (!mounted) return;
    if (outcome == ListInvitationOutcome.accepted ||
        outcome == ListInvitationOutcome.alreadyMember) {
      SnackBarUtils.showSuccess(
        context,
        context.l10n.listInvitationJoined(invitation.listName.orEmpty()),
      );
    } else {
      _showFailure(outcome);
    }
  }

  Future<void> _decline(
    ListInvitationsViewModel vm,
    SocialRequest invitation,
  ) async {
    final outcome = await vm.decline(invitation.id);
    if (!mounted) return;
    if (outcome == ListInvitationOutcome.declined) {
      SnackBarUtils.showSuccess(
        context,
        context.l10n.listInvitationDeclinedNotice,
      );
    } else {
      _showFailure(outcome);
    }
  }

  void _showFailure(ListInvitationOutcome outcome) {
    final l10n = context.l10n;
    final what = switch (outcome) {
      ListInvitationOutcome.offline => l10n.errorNetwork,
      ListInvitationOutcome.notAvailable => l10n.listInvitationNoLongerValid,
      _ => l10n.listInvitationActionFailed,
    };
    SnackBarUtils.showFailure(context, what: what);
  }

  Future<void> _block(
    ListInvitationsViewModel vm,
    SocialRequest invitation,
  ) async {
    // Built on first use: the friends view model loads the whole friend list.
    final friends = _friends ??=
        widget.friendsViewModel ?? ServiceLocator.get<FriendsViewModel>();
    final blocked = await BlockUserAction.confirmAndBlock(
      context,
      userId: invitation.fromUserId,
      displayName: ListInvitationCard.senderNameOf(context, invitation),
      viewModel: friends,
    );
    if (blocked) vm.dismissFrom(invitation.fromUserId);
  }
}
