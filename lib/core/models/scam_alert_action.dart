/// Action returned by [ScamAlertDialog] when dismissed or chosen by the user.
enum ScamAlertAction {
  /// Open existing contact to view its details.
  viewExisting,

  /// Merge the incoming card with the existing master contact record.
  mergeContact,

  /// Save the newly scanned card as a separate card (allowed even if same phone exists).
  saveAsAnotherCard,

  /// Dismiss the alert and do not save the new card.
  cancel,
}
