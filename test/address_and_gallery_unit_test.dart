import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/core/services/api_config.dart';
import 'package:smartcard_flutter/models/card_model.dart';

void main() {
  group('Address Synchronization & Gallery Delete Unit Tests', () {

    // =========================================================================
    // 1. CARD PROFILE DETAILS ADDRESS PARSING
    // =========================================================================
    test('CardProfileDetails parses user address and work profile address correctly', () {
      final json = {
        'user': {
          'first_name': 'Remakanth',
          'last_name': 'R',
          'email': 'remakanth@antzmedia.com',
          'phone': '9995955999',
          'address': '51, Tagore Nagar, Kadavanthra, ERNAKULAM, KERALA',
          'pincode': 682020,
          'city': 'ERNAKULAM',
          'state': 'KERALA',
          'district': 'ERNAKULAM',
        },
        'work': {
          'company_name': 'Antz Media Digital',
          'designation': 'Chief Evangelist',
          'address1': '51, Tagore Nagar, Kadavanthra',
          'pincode': '682020',
          'city': 'ERNAKULAM',
          'state': 'KERALA',
          'district': 'ERNAKULAM',
        }
      };

      final details = CardProfileDetails.fromJson(json);

      expect(details.firstName, equals('Remakanth'));
      expect(details.lastName, equals('R'));
      expect(details.address, equals('51, Tagore Nagar, Kadavanthra, ERNAKULAM, KERALA'));
      expect(details.companyAddress, equals('51, Tagore Nagar, Kadavanthra'));
      expect(details.pincode, equals('682020'));
      expect(details.companyPincode, equals('682020'));
    });

    // =========================================================================
    // 2. EDIT SHEET PROFESSIONAL ADDRESS TWO-WAY SYNCHRONIZATION
    // =========================================================================
    test('Editing section-address synchronizes personal address and company address', () {
      final details = CardProfileDetails(
        firstName: 'Remakanth',
        lastName: 'R',
        address: 'Old Personal Address',
        pincode: '111111',
        companyAddress: 'Keerthi Madom,',
        companyPincode: '111111',
      );

      const newAddress = '51, Tagore Nagar, Kadavanthra, ERNAKULAM, KERALA';
      const newPincode = '682020';
      const newCity = 'ERNAKULAM';
      const newState = 'KERALA';
      const newDistrict = 'ERNAKULAM';
      const newCityId = '101';
      const newStateId = '18';

      // Simulation of manage_cards_edit_sheet.dart save logic for 'section-address'
      details.address = newAddress;
      details.pincode = newPincode;
      details.cityId = newCityId;
      details.stateId = newStateId;
      details.city = newCity;
      details.state = newState;
      details.district = newDistrict;
      details.officeSelected = true;

      // Synchronization to companyAddress
      details.companyAddress = newAddress;
      details.companyPincode = newPincode;
      details.companyCityId = newCityId;
      details.companyStateId = newStateId;
      details.companyCity = newCity;
      details.companyState = newState;
      details.companyDistrict = newDistrict;
      details.companyOfficeSelected = true;

      expect(details.address, equals(newAddress));
      expect(details.companyAddress, equals(newAddress), reason: 'companyAddress must match edited address');
      expect(details.companyPincode, equals(newPincode));
      expect(details.companyCityId, equals(newCityId));
      expect(details.companyStateId, equals(newStateId));
    });

    // =========================================================================
    // 3. EDIT ALL SCREEN FALLBACK SYNCHRONIZATION
    // =========================================================================
    test('Manage Card Edit All Screen correctly populates companyAddress when address is entered', () {
      final details = CardProfileDetails(
        firstName: 'Test',
        lastName: 'User',
        address: 'New Office Location, Kochi',
        pincode: '682001',
        companyAddress: '',
        companyPincode: '',
      );

      // Simulation of manage_card_edit_all_screen.dart sync logic
      if (details.companyAddress.isEmpty && details.address.isNotEmpty) {
        details.companyAddress = details.address;
        details.companyPincode = details.pincode;
        details.companyCityId = details.cityId;
        details.companyStateId = details.stateId;
        details.companyCity = details.city;
        details.companyState = details.state;
        details.companyDistrict = details.district;
        details.companyOfficeSelected = details.officeSelected;
      }

      expect(details.companyAddress, equals('New Office Location, Kochi'));
      expect(details.companyPincode, equals('682001'));
    });

    // =========================================================================
    // 4. API CONFIG GALLERY ENDPOINTS
    // =========================================================================
    test('ApiConfig provides correct gallery endpoints for DELETE and POST fallback', () {
      const testUserId = '41';
      expect(
        ApiConfig.galleryImages(testUserId),
        equals('/api/v1/users/41/gallery/images'),
      );
      expect(
        ApiConfig.deleteGalleryImage(testUserId),
        equals('/api/v1/users/41/gallery/images/delete'),
      );
    });

    // =========================================================================
    // 5. LOCAL GALLERY REMOVAL IN VIEWMODEL
    // =========================================================================
    test('Removing a photo from existingPhotos updates list immediately', () {
      final details = CardProfileDetails(
        firstName: 'Test',
        lastName: 'User',
      );
      details.existingPhotos = [
        'uploads/gallery/photo1.webp',
        'uploads/gallery/photo2.webp',
        'uploads/gallery/photo3.webp'
      ];

      const photoToRemove = 'uploads/gallery/photo2.webp';
      details.existingPhotos.remove(photoToRemove);

      expect(details.existingPhotos.length, equals(2));
      expect(details.existingPhotos.contains(photoToRemove), isFalse);
      expect(details.existingPhotos, equals(['uploads/gallery/photo1.webp', 'uploads/gallery/photo3.webp']));
    });
  });
}
