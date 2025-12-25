// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:butlery/core/router/deferred_module_loader.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Widget that loads a deferred module and displays the route once loaded
class DeferredRouteLoader extends StatefulWidget {
  final String moduleName;
  final String routeName;
  final RouteSettings settings;

  const DeferredRouteLoader({
    super.key,
    required this.moduleName,
    required this.routeName,
    required this.settings,
  });

  @override
  State<DeferredRouteLoader> createState() => _DeferredRouteLoaderState();
}

class _DeferredRouteLoaderState extends State<DeferredRouteLoader> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadModule();
  }

  void _loadModule() {
    _loadFuture = DeferredModuleLoader.ensureLoaded(widget.moduleName);
  }

  void _retry() {
    setState(() {
      _loadModule();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ModuleLoadingScreen();
        }

        if (snapshot.hasError) {
          return ModuleLoadErrorScreen(
            error: snapshot.error,
            onRetry: _retry,
            onGoHome: () => Navigator.of(context)
                .pushNamedAndRemoveUntil(Routes.home, (route) => false),
          );
        }

        // Module loaded, build the actual route
        return _buildLoadedRoute();
      },
    );
  }

  Widget _buildLoadedRoute() {
    try {
      final module = DeferredModuleLoader.getModule(widget.moduleName);
      if (module == null) {
        return ModuleLoadErrorScreen(
          error: 'Module not found: ${widget.moduleName}',
          onRetry: _retry,
          onGoHome: () => Navigator.of(context)
              .pushNamedAndRemoveUntil(Routes.home, (route) => false),
        );
      }
      return module.buildRoute(widget.routeName, widget.settings);
    } catch (e) {
      return ModuleLoadErrorScreen(
        error: e,
        onRetry: _retry,
        onGoHome: () => Navigator.of(context)
            .pushNamedAndRemoveUntil(Routes.home, (route) => false),
      );
    }
  }
}

/// Loading screen shown while module is being loaded
class ModuleLoadingScreen extends StatelessWidget {
  const ModuleLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBeige,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primaryBlue,
              strokeWidth: 3,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              'Laddar...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error screen shown when module loading fails
class ModuleLoadErrorScreen extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback onGoHome;

  const ModuleLoadErrorScreen({
    super.key,
    this.error,
    required this.onRetry,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBeige,
      appBar: AppBar(
        title: const Text('Fel'),
        backgroundColor: AppColors.backgroundBeige,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: AppDimensions.iconSizeXl,
                color: AppColors.error,
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              Text(
                'Kunde inte ladda sidan',
                style: AppTextStyles.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'Ett fel uppstod vid laddning. Försök igen eller gå tillbaka.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: onGoHome,
                    icon: const Icon(Icons.home),
                    label: const Text('Till start'),
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Försök igen'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
