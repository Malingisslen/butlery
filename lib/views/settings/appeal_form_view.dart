import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/social/decision_detail_args.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/field_text_style.dart';
import 'package:butlery/viewmodels/settings/appeal_form_viewmodel.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/social/decision_labels.dart';
import 'package:butlery/widgets/styled/labeled_field.dart';

/// The in-app appeal: one text, one appeal per decision. Pops with `true`
/// once the server has accepted it.
class AppealFormView extends StatefulWidget {
  const AppealFormView({required this.args, super.key});

  final AppealFormArgs args;

  @override
  State<AppealFormView> createState() => _AppealFormViewState();
}

class _AppealFormViewState extends State<AppealFormView> {
  late final AppealFormViewModel _vm;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm = AppealFormViewModel(
      reportId: widget.args.outcome.reportId,
      role: widget.args.role,
      service: ServiceLocator.get<ModerationAppealsService>(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final ok = await _vm.submit();
    if (!mounted) return;
    if (ok) {
      SnackBarUtils.showSuccess(context, l10n.appealSent);
      Navigator.pop(context, true);
      return;
    }
    SnackBarUtils.showFailure(
      context,
      what: appealFailureText(l10n, _vm.failure ?? AppealFailure.other),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final owner = widget.args.role == AppealRole.owner;
    return ChangeNotifierProvider<AppealFormViewModel>.value(
      value: _vm,
      child: ButleryPage.undersida(
        title: l10n.appealFormTitle,
        showTabBar: false,
        body: Consumer<AppealFormViewModel>(
          builder: (context, vm, _) => ListView(
            padding: EdgeInsets.symmetric(
              horizontal: ButleryTopBar.sideMargin(context),
              vertical: AppDimensions.space16,
            ),
            children: [
              TintedNote.labelled(
                label: l10n.decisionOutcomeLabel,
                text: decisionHeadline(l10n, widget.args.outcome.decision),
              ),
              const SizedBox(height: AppDimensions.space16),
              Text(l10n.appealFormQuestion, style: AppTextStyles.titleBold),
              const SizedBox(height: AppDimensions.space4),
              Text(
                l10n.appealFormIntro,
                style: AppTextStyles.bodyMedium.copyWith(color: muted),
              ),
              const SizedBox(height: AppDimensions.space12),
              LabeledField(
                child: TextField(
                  controller: _controller,
                  enabled: !vm.isLoading,
                  style: fieldTextStyle(context, enabled: !vm.isLoading),
                  minLines: 5,
                  maxLines: 10,
                  maxLength: ModerationAppealsService.maxTextLength,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  onChanged: vm.setText,
                  decoration: InputDecoration(
                    hintText: l10n.appealFormHint,
                    counterText: l10n.appealCounter(
                      vm.text.length,
                      ModerationAppealsService.maxTextLength,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.space8),
              Text(
                owner ? l10n.appealFormOnceOwner : l10n.appealFormOnceReporter,
                style: AppTextStyles.captionBase.copyWith(color: muted),
              ),
              const SizedBox(height: AppDimensions.space16),
              FilledButton(
                onPressed: vm.canSubmit ? _submit : null,
                child: Text(l10n.appealSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
