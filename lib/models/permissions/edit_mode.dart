/// lib/models/permissions/edit_mode.dart

enum EditMode {
  owner, // Äger receptet - kan alltid redigera original
  collaborative, // Kollaborativ redigering - ändringar synkas
  readOnlyWithFork, // Bara läsning + "Spara min kopia"
  noAccess, // Ingen åtkomst
}

extension EditModeExtension on EditMode {
  bool get canEdit => this == EditMode.owner || this == EditMode.collaborative;
  bool get canFork => this != EditMode.noAccess;
  bool get showForkButton =>
      this == EditMode.readOnlyWithFork || this == EditMode.collaborative;

  String get description {
    switch (this) {
      case EditMode.owner:
        return 'Du äger detta recept';
      case EditMode.collaborative:
        return 'Du redigerar tillsammans med andra';
      case EditMode.readOnlyWithFork:
        return 'Skrivskyddat - du kan spara din egen kopia';
      case EditMode.noAccess:
        return 'Ingen åtkomst';
    }
  }
}
