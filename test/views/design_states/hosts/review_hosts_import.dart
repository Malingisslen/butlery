/// Hosts for the import views the register had not compared.
library;

import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/viewmodels/archive_import_viewmodel.dart';
import 'package:butlery/viewmodels/import/voice_import_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/views/file_import_view.dart';
import 'package:butlery/views/fran_sociala_medier_view.dart';
import 'package:butlery/views/importera_fran_arkiv_view.dart';
import 'package:butlery/views/photo_import_view.dart';
import 'package:butlery/views/voice_import_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart'
    show MockSearchService;
import '../state_host.dart';

class _MockText extends Mock implements TextImportViewModel {}

class _MockUser extends Mock implements UserService {}

class _FakeVoiceCapture extends Fake implements VoiceCaptureService {
  @override
  Future<bool> prepareModel() async => true;

  @override
  Future<void> cancelRecording() async {}
}

class _GrantedGateway implements PermissionGateway {
  @override
  Future<PermissionStatus> checkStatus(Permission permission) async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> request(Permission permission) async =>
      PermissionStatus.granted;

  @override
  Future<bool> openSettings() async => true;
}

final reviewImportHosts = <String, StateHost>{
  'FileImportView': StateHost(
    build: (ctx) async {
      TestServiceLocator.registerMock<ImportManager>(MockImportManager());
      return const FileImportView();
    },
  ),
  'FranSocialaMedierView': StateHost(
    build: (ctx) async {
      const pasted =
          'Pannkakor\n\nIngredienser:\n2 dl vetemjöl\n3 dl mjölk\n2 ägg\n'
          '\nGör så här:\nVispa ihop smeten och stek i smör.';
      final vm = _MockText();
      when(() => vm.canParse).thenReturn(true);
      when(() => vm.error).thenReturn(null);
      when(() => vm.hasError).thenReturn(false);
      when(() => vm.inputText).thenReturn(pasted);
      when(() => vm.isParsing).thenReturn(false);
      when(() => vm.hasMultipleParsedRecipes).thenReturn(false);
      when(() => vm.sourceUrl).thenReturn(null);
      when(() => vm.updateInputText(any())).thenReturn(null);
      when(() => vm.setSourceUrl(any())).thenReturn(null);
      when(vm.parseText).thenAnswer((_) async => true);
      TestServiceLocator.registerMock<TextImportViewModel>(vm);
      final user = _MockUser();
      when(
        () => user.allergenPreferences,
      ).thenReturn(UserAllergenPreferences.defaults);
      TestServiceLocator.registerMock<UserService>(user);
      return const FranSocialaMedierView(initialText: pasted);
    },
  ),
  'ImporteraFranArkivView': StateHost(
    build: (ctx) async {
      final recipes = MockUnifiedRecipeService();
      final search = MockSearchService();
      TestServiceLocator.registerFactory<ArchiveImportViewModel>(
        () => ArchiveImportViewModel(
          recipeService: recipes,
          searchService: search,
        ),
      );
      return const ImporteraFranArkivView();
    },
  ),
  'PhotoImportView': StateHost(
    build: (ctx) async {
      final vm = MockPhotoImportViewModel()..setPhotoImportState();
      when(vm.loadPersistedDraft).thenAnswer((_) async => null);
      when(() => vm.isHeirloom).thenReturn(false);
      when(() => vm.heirloomWriterName).thenReturn('');
      when(() => vm.heirloomNote).thenReturn('');
      when(() => vm.heirloomYear).thenReturn(null);
      when(() => vm.isOfflineQueued).thenReturn(false);
      when(() => vm.qualityScore).thenReturn(null);
      when(() => vm.recommendations).thenReturn(null);
      when(() => vm.canRetryOcr).thenReturn(false);
      when(() => vm.canAddPage).thenReturn(false);
      when(() => vm.hasMultiplePages).thenReturn(false);
      when(() => vm.pageImages).thenReturn(<Uint8List>[]);
      when(() => vm.permissionNotice).thenReturn(null);
      when(() => vm.dispose()).thenReturn(null);
      TestServiceLocator.registerMock<PhotoImportViewModel>(vm);
      final user = _MockUser();
      when(
        () => user.allergenPreferences,
      ).thenReturn(UserAllergenPreferences.defaults);
      TestServiceLocator.registerMock<UserService>(user);
      return const PhotoImportView();
    },
  ),
  'VoiceImportView': StateHost(
    build: (ctx) async {
      final manager = MockImportManager();
      TestServiceLocator.registerFactory<VoiceImportViewModel>(
        () => VoiceImportViewModel(
          importManager: manager,
          voiceCapture: _FakeVoiceCapture(),
        ),
      );
      return VoiceImportView(permissionGateway: _GrantedGateway());
    },
  ),
};
