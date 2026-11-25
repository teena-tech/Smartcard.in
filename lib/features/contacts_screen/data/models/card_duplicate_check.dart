import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';

enum CardDuplicateType {
  none,
  exactDuplicate,          // Exact same card: identical ID, card URL, or same phone + same person/entity
  sameNumberDifferentCard, // Same card/phone number, but different physical card or different person/company
}

class CardDuplicateCheck {
  final CardDuplicateType type;
  final ScannedContactModel? existingContact;
  final String? matchedField;

  const CardDuplicateCheck({
    required this.type,
    this.existingContact,
    this.matchedField,
  });

  bool get isDuplicate => type == CardDuplicateType.exactDuplicate;
  bool get isExact => type == CardDuplicateType.exactDuplicate;
  bool get isSameNumberDifferentCard => type == CardDuplicateType.sameNumberDifferentCard;
}
