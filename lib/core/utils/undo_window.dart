/// The single undo window for every class-1 operation.
///
/// `add` and `delete` are class 1
/// and carry a **7 s Ångra-snackbar**; class 3 (`update`, `check`, `assign`,
/// `reorder`) carries no friction at all.
///
/// Pure Dart on purpose, so view models can name the window. It is the
/// snackbar's `duration` only. No deferred commit may run on a timer of this
/// length: Flutter starts a snackbar's timer after its entrance animation, and
/// only once it is at the head of the queue, so a parallel timer would commit
/// while Ångra is still on screen. Deferred commits run when the snackbar
/// closes instead (`UndoSnackBar.showDeferred`).
const Duration kUndoWindow = Duration(seconds: 7);
