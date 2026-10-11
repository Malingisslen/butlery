// lib/views/social/friends_list/find_friends_sheet.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/social/friends_list/invitation_link_share.dart';
import 'package:butlery/views/social/friends_list/search_tab.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

/// Opens the "Hitta vänner" sheet: friend search plus the profile-link share.
/// The sheet is its own route, so it gets [viewModel] by value.
Future<void> showFindFriendsSheet(
  BuildContext context,
  FriendsViewModel viewModel,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => ChangeNotifierProvider<FriendsViewModel>.value(
      value: viewModel,
      child: const _FindFriendsSheet(),
    ),
  );
  // A query left in the view model would filter the friends list behind the
  // sheet and greet the next opening with stale results.
  await viewModel.updateSearch('');
}

class _FindFriendsSheet extends StatefulWidget {
  const _FindFriendsSheet();

  @override
  State<_FindFriendsSheet> createState() => _FindFriendsSheetState();
}

class _FindFriendsSheetState extends State<_FindFriendsSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    setState(() => _query = query);
    context.read<FriendsViewModel>().updateSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final margin = AppDimensions.layoutMarginOf(context);
    final viewModel = context.watch<FriendsViewModel>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.socialFindFriends,
                      style: AppTextStyles.subpageTitle,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingM),
                  ButlerySearchBox(
                    controller: _controller,
                    hintText: l10n.socialSearchNameOrEmailHint,
                    autofocus: true,
                    onChanged: _onChanged,
                  ),
                  ButleryListSection(
                    rows: [
                      ButleryListRow(
                        label: l10n.socialShareProfileLink,
                        leading: ButleryIcons.link,
                        onTap: () => InvitationLinkShare.shareInvitationLink(
                          context,
                          viewModel,
                        ),
                      ),
                      ButleryListRow(
                        label: l10n.commonCopyLink,
                        leading: ButleryIcons.copy,
                        onTap: () => InvitationLinkShare.copyInvitationLink(
                          context,
                          viewModel,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_query.isNotEmpty)
              Expanded(
                child: SearchTab.build(context, viewModel, _query),
              ),
          ],
        ),
      ),
    );
  }
}
