import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:butlery/views/veckomeny_view/veckomeny_notices.dart';
import 'package:provider/provider.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/menu/calendar_weekly_menu_widget.dart';
import 'package:butlery/widgets/menu/menu_content_widgets.dart';
import 'package:butlery/widgets/menu/veckomeny_cloche_reveal.dart';
import 'package:butlery/widgets/menu/veckomeny_planning_cancel_footer.dart';
import 'package:butlery/widgets/realtime/conflict_banner.dart';
import 'package:butlery/widgets/voice/voice_prompt_button.dart';
import 'package:butlery/widgets/menu/veckomeny_prompt_row.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';
import 'package:butlery/widgets/social/family_presence_bar.dart';

/// The week menu's page body: the planning panel on top and the calendar,
/// suggestion or progress below it.
class VeckomenyBody extends StatelessWidget {
  const VeckomenyBody({
    super.key,
    required this.viewModel,
    required this.viewMode,
    required this.realtimeMenuId,
    required this.promptController,
    required this.promptFocusNode,
    required this.revealing,
    required this.draftCard,
    required this.onSetViewMode,
    required this.onGenerate,
    required this.onCancelPlanning,
    required this.onPromptChanged,
    required this.onRevealDone,
  });

  final MenuViewModel viewModel;
  final VeckomenyViewMode viewMode;
  final String? realtimeMenuId;
  final TextEditingController promptController;
  final FocusNode promptFocusNode;
  final bool revealing;
  final Widget? draftCard;
  final Future<void> Function(VeckomenyViewMode mode) onSetViewMode;
  final Future<void> Function() onGenerate;
  final VoidCallback onCancelPlanning;
  final VoidCallback onPromptChanged;
  final VoidCallback onRevealDone;

  static const double _minContentHeight = 150;

  @override
  Widget build(BuildContext context) {
    // At large text on a short phone the top of the page took the whole
    // height and left the planning panel none (BUT-2341), so it scrolls
    // once it would leave the content under [_minContentHeight], and never
    // takes more than a third of a body shorter than that.
    return LayoutBuilder(
      builder: (_, constraints) => Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.max(
                constraints.maxHeight / 3,
                constraints.maxHeight - _minContentHeight,
              ),
            ),
            child: SingleChildScrollView(
              primary: false,
              child: Column(
                children: [
                  LayoutComponents.offlineIndicator(),
                  // BUT-407: online-members presence bar (union across groups).
                  const FamilyPresenceBar(),
                  // BUT-408: live cooking session card for the user's groups.
                  const VeckomenyCookingSessionCard(),
                  ?draftCard,
                  // A new generation would overwrite the menu for everyone.
                  if (realtimeMenuId == null)
                    Padding(
                      padding: AppDimensions.responsiveContentPadding(
                        context,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: AppDimensions.space12,
                        children: [
                          VeckomenyViewModeToggle(
                            mode: viewMode,
                            onSelect: (mode) => unawaited(onSetViewMode(mode)),
                          ),
                          VeckomenyPromptRow(
                            controller: promptController,
                            focusNode: promptFocusNode,
                            isGenerating: viewModel.isGenerating,
                            hasMenu: viewModel.hasMenu,
                            // A planned week asks its question in the field
                            // alone; the label and button come back once
                            // there is text or no week yet.
                            compact:
                                viewMode == VeckomenyViewMode.kalender &&
                                context
                                    .watch<WeeklyMenuPlanViewModel>()
                                    .hasEntries &&
                                promptController.text.isEmpty,
                            onClear: () {
                              promptController.clear();
                              onPromptChanged();
                            },
                            onChanged: onPromptChanged,
                            onGenerate: () => unawaited(onGenerate()),
                            // Voice prompt (kb-whisper plan): transcript lands
                            // EDITABLE here — the user reviews before generating.
                            voiceButton: VoicePromptButton(
                              enabled: !viewModel.isGenerating,
                              onTranscript: (text) {
                                promptController.text = text;
                                promptController.selection =
                                    TextSelection.collapsed(
                                      offset: text.length,
                                    );
                                promptFocusNode.requestFocus();
                                onPromptChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (realtimeMenuId case final id?)
                    ConflictBanner(filterDocId: id),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: AppDimensions.responsiveHorizontalPadding(context),
                    child: viewModel.isGenerating
                        ? SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const VeckomenyGeneratingOverlay(),
                                const SizedBox(height: AppDimensions.space16),
                                VeckomenyPlanningCancelFooter(
                                  onCancel: onCancelPlanning,
                                ),
                              ],
                            ),
                          )
                        : viewMode == VeckomenyViewMode.kalender &&
                              realtimeMenuId == null
                        ? SingleChildScrollView(
                            // BUT-1611: per-meal "who's home" lives inside the
                            // calendar (faces on each slot + a collapsible
                            // week overview), not a separate strip.
                            child: CalendarWeeklyMenuWidget(
                              onRefinePrompt: promptFocusNode.requestFocus,
                            ),
                          )
                        : Column(
                            children: [
                              // P5-U25: fewer dishes than asked is a partial
                              // outcome, named above the list.
                              if (viewModel.partialOutcome != null &&
                                  !viewModel.hasError)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppDimensions.space8,
                                  ),
                                  child: VeckomenyPartialResult(
                                    outcome: viewModel.partialOutcome!,
                                  ),
                                ),
                              Expanded(
                                child:
                                    viewModel.noMatchOutcome != null &&
                                        !viewModel.hasError
                                    // P6-U01: nothing matched is its own
                                    // outcome, never "Ett fel uppstod".
                                    ? VeckomenyNoMatch(
                                        outcome: viewModel.noMatchOutcome!,
                                        onEditPrompt:
                                            promptFocusNode.requestFocus,
                                        onPlanYourself: () => unawaited(
                                          onSetViewMode(
                                            VeckomenyViewMode.kalender,
                                          ),
                                        ),
                                      )
                                    : MenuContentWidgets.buildMenuContent(
                                        context,
                                        viewModel: viewModel,
                                        votingViewModel:
                                            viewModel.votingViewModel,
                                        onRetry:
                                            promptController.text.isNotEmpty
                                            ? () => unawaited(onGenerate())
                                            : null,
                                      ),
                              ),
                            ],
                          ),
                  ),
                ),
                if (revealing)
                  Positioned.fill(
                    child: VeckomenyClocheReveal(
                      onDone: onRevealDone,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
