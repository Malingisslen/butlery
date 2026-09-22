/// The single undo window for every class-1 operation.
///
/// produktregler.md:129-132 (§ 2.4, BUT-954): `add` and `delete` are class 1
/// and carry a **7 s Ångra-snackbar**; class 3 (`update`, `check`, `assign`,
/// `reorder`) carries no friction at all. produktregler.md:107 (chat deletion)
/// and :755 (inbox removal) repeat the same seven seconds, so this is the
/// class's number, not one list's.
///
/// Pure Dart on purpose, so view models can name the window. It is the
/// snackbar's `duration` only. No deferred commit may run on a timer of this
/// length: Flutter starts a snackbar's timer after its entrance animation, and
/// only once it is at the head of the queue, so a parallel timer would commit
/// while Ångra is still on screen. Deferred commits run when the snackbar
/// closes instead (`UndoSnackBar.showDeferred`).
const Duration kUndoWindow = Duration(seconds: 7);
