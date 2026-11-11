Future<bool> recoverFromPricingConflict({
  required Future<bool> Function() recalculate,
  required Future<bool> Function() confirmUpdatedPrice,
  required Future<bool> Function() retrySubmission,
}) async {
  if (!await recalculate()) return false;
  if (!await confirmUpdatedPrice()) return false;
  return retrySubmission();
}
