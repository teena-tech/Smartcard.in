from pathlib import Path

replacements = {
    'lib/repositories/card_repository.dart': {
        "'/api/users/$userId/subscription-details'": "ApiConfig.subscriptionDetails(userId)",
        '"/api/users/$userId/subscription-details"': 'ApiConfig.subscriptionDetails(userId)',
        "'/api/users/$userId/subscription-coupon'": "ApiConfig.subscriptionCoupon(userId)",
        '"/api/users/$userId/subscription-coupon"': 'ApiConfig.subscriptionCoupon(userId)',
        "'/api/users/$userId/subscription-payment/confirm'": "ApiConfig.subscriptionConfirm(userId)",
        '"/api/users/$userId/subscription-payment/confirm"': 'ApiConfig.subscriptionConfirm(userId)',
    },
    'lib/repositories/dashboard_repository.dart': {
        "'/api/users/$userId/profile'": "ApiConfig.userProfile(userId)",
        '"/api/users/$userId/profile"': 'ApiConfig.userProfile(userId)',
    },
    'lib/repositories/theme_repository.dart': {
        "'/api/themes/$userId'": "ApiConfig.theme(userId)",
        '"/api/themes/$userId"': 'ApiConfig.theme(userId)',
        "'/api/themes/background-images'": "ApiConfig.backgroundImages",
        '"/api/themes/background-images"': 'ApiConfig.backgroundImages',
        "'/api/themes/$userId/solid-colors'": "ApiConfig.themeSolidColors(userId)",
        '"/api/themes/$userId/solid-colors"': 'ApiConfig.themeSolidColors(userId)',
        "'/api/themes/$userId/background'": "ApiConfig.themeBackground(userId)",
        '"/api/themes/$userId/background"': 'ApiConfig.themeBackground(userId)',
        "'/api/themes/$userId/background-upload'": "ApiConfig.themeBackgroundUpload(userId)",
        '"/api/themes/$userId/background-upload"': 'ApiConfig.themeBackgroundUpload(userId)',
        "'/api/themes/$userId/logo-colors'": "ApiConfig.themeLogoColors(userId)",
        '"/api/themes/$userId/logo-colors"': 'ApiConfig.themeLogoColors(userId)',
        "'/api/themes/$userId/clear-background'": "ApiConfig.clearBackground(userId)",
        '"/api/themes/$userId/clear-background"': 'ApiConfig.clearBackground(userId)',
        "'/api/themes/templates'": "ApiConfig.templates",
        '"/api/themes/templates"': 'ApiConfig.templates',
        "'/api/themes/$userId/template'": "ApiConfig.themeTemplate(userId)",
        '"/api/themes/$userId/template"': 'ApiConfig.themeTemplate(userId)',
    },
    'lib/core/services/backend_sync_service.dart': {
        "'/api/users/me/contacts'": "ApiConfig.qrContacts",
        '"/api/users/me/contacts"': 'ApiConfig.qrContacts',
    },
    'lib/core/services/subscription_api_service.dart': {
        "'/api/users/$userId/subscription-details'": "ApiConfig.subscriptionDetails(userId)",
        '"/api/users/$userId/subscription-details"': 'ApiConfig.subscriptionDetails(userId)',
        "'/api/users/$userId/subscription-coupon'": "ApiConfig.subscriptionCoupon(userId)",
        '"/api/users/$userId/subscription-coupon"': 'ApiConfig.subscriptionCoupon(userId)',
        "'/api/users/$userId/subscription-payment/order'": "ApiConfig.subscriptionOrder(userId)",
        '"/api/users/$userId/subscription-payment/order"': 'ApiConfig.subscriptionOrder(userId)',
        "'/api/users/$userId/subscription-payment/confirm'": "ApiConfig.subscriptionConfirm(userId)",
        '"/api/users/$userId/subscription-payment/confirm"': 'ApiConfig.subscriptionConfirm(userId)',
        "'/api/users/$userId/subscription-payment/failure'": "ApiConfig.subscriptionFailure(userId)",
        '"/api/users/$userId/subscription-payment/failure"': 'ApiConfig.subscriptionFailure(userId)',
    },
    'lib/core/services/scanner_api_service.dart': {
        "'/api/users/me/contacts'": "ApiConfig.qrContacts",
        '"/api/users/me/contacts"': 'ApiConfig.qrContacts',
        "'/api/users/me/contacts/preview'": "ApiConfig.qrPreview",
        '"/api/users/me/contacts/preview"': 'ApiConfig.qrPreview',
        "'/api/users/me/contacts'": "ApiConfig.qrContacts",
        "'/api/users/me/contacts/$contactId'": "ApiConfig.qrDelete(contactId)",
        '"/api/users/me/contacts/$contactId"': 'ApiConfig.qrDelete(contactId)',
    },
    'lib/repositories/user_repository.dart': {
        "'/api/users/$userId/profile'": "ApiConfig.userProfile(userId)",
        '"/api/users/$userId/profile"': 'ApiConfig.userProfile(userId)',
        "'/api/users/$userId/password-change'": "ApiConfig.passwordChange(userId)",
        '"/api/users/$userId/password-change"': 'ApiConfig.passwordChange(userId)',
        "'/api/users/$userId/gallery'": "ApiConfig.userGallery(userId)",
        '"/api/users/$userId/gallery"': 'ApiConfig.userGallery(userId)',
        "'/api/users/$userId/profile-image'": "ApiConfig.userProfileImage(userId)",
        '"/api/users/$userId/profile-image"': 'ApiConfig.userProfileImage(userId)',
        "'/api/users/$userId/company-logo'": "ApiConfig.companyLogo(userId)",
        '"/api/users/$userId/company-logo"': 'ApiConfig.companyLogo(userId)',
        "'/api/users/$userId/support/context'": "ApiConfig.supportContext(userId)",
        '"/api/users/$userId/support/context"': 'ApiConfig.supportContext(userId)',
        "'/api/users/$userId/support/messages'": "ApiConfig.supportMessages(userId)",
        '"/api/users/$userId/support/messages"': 'ApiConfig.supportMessages(userId)',
        "'/api/user-reports'": "ApiConfig.userReports",
        '"/api/user-reports"': 'ApiConfig.userReports',
        "'/api/user-reports/$reportId'": "ApiConfig.userReport(reportId)",
        '"/api/user-reports/$reportId"': 'ApiConfig.userReport(reportId)',
        "'/api/user-reports/$reportId/reply'": "ApiConfig.replyUserReport(reportId)",
        '"/api/user-reports/$reportId/reply"': 'ApiConfig.replyUserReport(reportId)',
        "'/api/users/$userId/gallery/images'": "ApiConfig.galleryImages(userId)",
        '"/api/users/$userId/gallery/images"': 'ApiConfig.galleryImages(userId)',
        "'/api/users/$userId/gallery/youtube-links'": "ApiConfig.galleryYoutubeLinks(userId)",
        '"/api/users/$userId/gallery/youtube-links"': 'ApiConfig.galleryYoutubeLinks(userId)',
        "'/api/users/$userId/additional-card'": "ApiConfig.additionalCard(userId)",
        '"/api/users/$userId/additional-card"': 'ApiConfig.additionalCard(userId)',
        "'/api/users/$userId/additional-card/$cardUserId'": "ApiConfig.deleteAdditionalCard(userId, cardUserId)",
        '"/api/users/$userId/additional-card/$cardUserId"': 'ApiConfig.deleteAdditionalCard(userId, cardUserId)',
        "'/api/users/$userId/primary-card/$cardUserId'": "ApiConfig.primaryCard(userId, cardUserId)",
        '"/api/users/$userId/primary-card/$cardUserId"': 'ApiConfig.primaryCard(userId, cardUserId)',
        "'/api/users/$userId/suspension'": "ApiConfig.selfSuspension(userId)",
        '"/api/users/$userId/suspension"': 'ApiConfig.selfSuspension(userId)',
        "'/api/users/$userId/phone-otp/send'": "ApiConfig.sendProfileOtp(userId)",
        '"/api/users/$userId/phone-otp/send"': 'ApiConfig.sendProfileOtp(userId)',
        "'/api/users/$userId/phone-otp/verify'": "ApiConfig.verifyProfileOtp(userId)",
        '"/api/users/$userId/phone-otp/verify"': 'ApiConfig.verifyProfileOtp(userId)',
    },
}

imports = {
    'lib/repositories/card_repository.dart': "import '../core/services/api_config.dart';\n",
    'lib/repositories/dashboard_repository.dart': "import '../core/services/api_config.dart';\n",
    'lib/repositories/theme_repository.dart': "import '../core/services/api_config.dart';\n",
    'lib/core/services/backend_sync_service.dart': "import '../core/services/api_config.dart';\n",
    'lib/core/services/subscription_api_service.dart': "import '../core/services/api_config.dart';\n",
    'lib/core/services/scanner_api_service.dart': "import '../core/services/api_config.dart';\n",
    'lib/repositories/user_repository.dart': "import '../core/services/api_config.dart';\n",
}

root = Path('d:/smartycard/smartycard/smartcard_flutter')
for relpath, repls in replacements.items():
    path = root / relpath
    text = path.read_text(encoding='utf-8')
    original = text
    for old, new in repls.items():
        text = text.replace(old, new)
    if relpath in imports and imports[relpath].strip() not in text:
        lines = text.splitlines(True)
        insert_index = 0
        for i, line in enumerate(lines):
            if line.startswith('import '):
                insert_index = i + 1
        lines.insert(insert_index, imports[relpath])
        text = ''.join(lines)
    if text != original:
        path.write_text(text, encoding='utf-8')
        print(f'Updated {relpath}')
    else:
        print(f'No changes for {relpath}')
