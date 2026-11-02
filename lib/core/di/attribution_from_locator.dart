import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/attribution_source.dart';
import 'package:butlery/services/user_service.dart';

/// An [AttributionSource] that reads whichever [UserService] is registered at
/// each call, for the DI modules and for the repositories and view models that
/// build their own.
AttributionSource attributionSourceFromLocator() =>
    AttributionSource(userService: ServiceLocator.tryGet<UserService>);
