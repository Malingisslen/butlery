/// The single undo window for every class-1 operation.
///
/// produktregler.md:129-132 (§ 2.4, BUT-954): `add` and `delete` are class 1
/// and carry a **7 s Ångra-snackbar**; class 3 (`update`, `check`, `assign`,
/// `reorder`) carries no friction at all. produktregler.md:107 (chat deletion)
/// and :755 (inbox removal) repeat the same seven seconds, so this is the
/// class's number, not one list's.
///
/// Pure Dart on purpose: the snackbar primitive (`SnackBarUtils.showUndo`)
/// and every deferred-commit timer (`RecipeDeleteManager`,
/// `RecipeManagementHandler`) read this one constant, so the button can never
/// stay pressable after the delete it offers to undo has been committed.
const Duration kUndoWindow = Duration(seconds: 7);
