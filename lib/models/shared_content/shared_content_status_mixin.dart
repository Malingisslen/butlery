import 'package:butlery/models/shared_content/base_shared_content_model.dart';

/// Empty mixin kept for backward compatibility.
/// Status tracking now handled by repository layer using Firestore subcollections.
mixin SharedContentStatusMixin<TContent> on BaseSharedContentModel<TContent> {}
