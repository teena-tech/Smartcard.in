Edit

இதுதான் நீங்கள் Flutter-ல் build செய்ய வேண்டிய advanced automatic business-card scanner-ன் target behavior.

இந்த image-ல் காட்டப்பட்ட flow

Camera → Card Detection → 4 Corners → Position Check → Stable Detection → Auto Capture → Perspective Correction → OCR → Edit → Save

முக்கியமாக இது fixed rectangle scanner இல்லை.

Card இப்படி இருந்தாலும்:

        ╱────────────────╲
       ╱                  ╲
      │    BUSINESS CARD   │
       ╲                  ╱
        ╲────────────────╱

Flutter/OpenCV actual 4 corners கண்டுபிடித்து அந்த shape-ஐ follow செய்யும்.

Flutter implementation architecture
Flutter Camera
      │
      ▼
CameraImage frames
      │
      ▼
OpenCV / CV processing
      │
      ├── Grayscale
      ├── Gaussian Blur
      ├── Canny Edge
      ├── Contours
      ├── Polygon Approximation
      └── 4-Corner Detection
      │
      ▼
CardDetector
      │
      ├── Card found?
      ├── Rectangle/quadrilateral?
      ├── Area sufficient?
      ├── Correct aspect ratio?
      ├── Blur acceptable?
      └── Stable for N frames?
      │
      ▼
Auto Capture
      │
      ▼
Perspective Transform
      │
      ▼
Crop + Enhance
      │
      ▼
OCR
      │
      ▼
Name / Company / Phone / Email
      │
      ▼
User Review
      │
      ▼
Save Contact
Flutter-ல் முக்கியமாக பிரிக்க வேண்டிய classes
lib/
├── features/
│   └── business_card_scanner/
│       ├── data/
│       │   ├── card_detector.dart
│       │   ├── perspective_transform.dart
│       │   └── ocr_service.dart
│       │
│       ├── domain/
│       │   ├── card_corners.dart
│       │   ├── detected_card.dart
│       │   └── contact_data.dart
│       │
│       ├── presentation/
│       │   ├── scanner_screen.dart
│       │   ├── scanner_overlay.dart
│       │   ├── detection_animation.dart
│       │   └── contact_review_screen.dart
│       │
│       └── controller/
│           └── scanner_controller.dart
Scanner state
enum ScannerState {
  searching,
  detected,
  adjusting,
  stable,
  capturing,
  processing,
  completed,
  error,
}

இதனால் UI state தெளிவாக இருக்கும்:

SEARCHING
   ↓
DETECTED
   ↓
ADJUSTING
   ↓
STABLE
   ↓
CAPTURING
   ↓
PROCESSING
   ↓
COMPLETED
மிக முக்கியமான logic

Card ஒருமுறை detect ஆனதற்காக capture செய்யக்கூடாது.

உதாரணமாக:

if (detectedCard != null) {

  if (isCardStable(detectedCard)) {

    stableFrameCount++;

  } else {

    stableFrameCount = 0;
  }

  if (stableFrameCount >= requiredFrames) {

    await autoCapture();

  }
}

இதுதான் "Hold steady → automatically capture" behavior.

இன்னும் advanced ஆக செய்ய வேண்டியது

Production SmartCards scanner-ல் நான் இந்த checks-ஐ சேர்ப்பேன்:

✅ 4-corner detection
✅ Portrait + landscape card
✅ Perspective correction
✅ Card size validation
✅ Aspect-ratio validation
✅ Blur detection
✅ Glare detection
✅ Partial-card rejection
✅ Edge confidence
✅ Stable-frame detection
✅ Auto capture
✅ Haptic feedback
✅ Capture animation
✅ OCR confidence
✅ Duplicate-contact detection
✅ Manual correction before saving

அடுத்ததாக Flutter-க்கு actual advanced code எழுதும்போது, camera + OpenCV/image-processing pipeline + perspective correction + automatic capture + animated corner overlay ஆகியவற்றை சேர்த்து ஒரு working scanner screen ஆக கட்டலாம்.

give thie exact in sample flutter dart code note givem the all desitls sn sample code this sxact code in flutter dart now

Yes. Below is a real Flutter/Dart sample architecture for the automatic business-card scanner you described.

One important distinction first: the earlier OpenCV-style code was an algorithm example, not a complete production Flutter implementation. For a real app, the camera stream, native image processing, four-corner detection, stability logic, capture, perspective correction, and OCR need to be connected properly.

For the fastest production-quality prototype, Google's ML Kit Document Scanner is attractive because it already provides automatic document detection, edge detection, automatic capture, rotation, cropping and image output. The current Flutter plugin is google_mlkit_document_scanner: ^0.5.0, but its current implementation is Android-only despite the package metadata showing iOS stubs; its documentation explicitly says the feature is only available on Android.

If you need your own custom SmartCards UI on both Android and iOS, use the camera plugin for the live stream and implement the detection pipeline yourself/native. The current camera package supports Android, iOS and Web and exposes image streams.

1. Target Flutter screen

The scanner should behave like this:

┌──────────────────────────────┐
│ ← Scan Business Card      ⚡ │
│                              │
│                              │
│      CAMERA PREVIEW          │
│                              │
│        ╭────────────╮        │
│       ╱              ╲       │
│      │   BUSINESS     │      │
│      │      CARD      │      │
│       ╲              ╱       │
│        ╰────────────╯        │
│                              │
│       ✓ Card detected        │
│       Hold steady...         │
│                              │
│             ◉                │
│                              │
└──────────────────────────────┘

No manual capture button is required when the card becomes stable.

2. Project structure
lib/
│
├── main.dart
│
├── features/
│   └── business_card_scanner/
│       │
│       ├── models/
│       │   ├── card_corners.dart
│       │   ├── detected_card.dart
│       │   └── scanner_state.dart
│       │
│       ├── services/
│       │   ├── camera_service.dart
│       │   ├── card_detection_service.dart
│       │   ├── image_processing_service.dart
│       │   └── ocr_service.dart
│       │
│       ├── controllers/
│       │   └── scanner_controller.dart
│       │
│       ├── widgets/
│       │   ├── scanner_overlay.dart
│       │   ├── corner_painter.dart
│       │   └── scanner_status.dart
│       │
│       └── screens/
│           ├── business_card_scanner_screen.dart
│           └── contact_review_screen.dart
│
└── core/
    └── theme/
        └── app_theme.dart
3. Dependencies

For the custom camera implementation, start with:

dependencies:
  flutter:
    sdk: flutter

  camera: ^0.12.0+2
  path_provider: ^2.1.5
  image: ^4.5.4
  google_mlkit_text_recognition: ^0.15.0

The current camera package supports camera preview, image capture and image-buffer streaming.

For OCR, use Google's text-recognition plugin rather than the umbrella google_ml_kit package; the ML Kit Flutter documentation recommends consuming only the specific plugin needed.

For the first Android prototype, you can alternatively add:

google_mlkit_document_scanner: ^0.5.0

That already handles automatic document detection/capture/cropping, so it is useful for validating the UX before implementing your own detector.

4. Scanner state

Create:

scanner_state.dart

enum ScannerState {
  initializing,

  searching,

  detected,

  adjusting,

  stable,

  capturing,

  processing,

  completed,

  error,
}
5. Card corner model

Create:

card_corners.dart

import 'package:flutter/material.dart';

class CardCorners {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  const CardCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  List<Offset> get points => [
        topLeft,
        topRight,
        bottomRight,
        bottomLeft,
      ];

  Offset get center {
    return Offset(
      (topLeft.dx +
              topRight.dx +
              bottomRight.dx +
              bottomLeft.dx) /
          4,
      (topLeft.dy +
              topRight.dy +
              bottomRight.dy +
              bottomLeft.dy) /
          4,
    );
  }
}
6. Detected card model

Create:

detected_card.dart

import 'card_corners.dart';

class DetectedCard {
  final CardCorners corners;

  final double area;

  final double confidence;

  final double aspectRatio;

  const DetectedCard({
    required this.corners,
    required this.area,
    required this.confidence,
    required this.aspectRatio,
  });

  bool get isGoodQuality {
    return confidence >= 0.75 &&
        aspectRatio >= 1.3 &&
        aspectRatio <= 2.2;
  }
}

A normal business card is roughly landscape-oriented, but don't make the detector dependent on one exact ratio. Real cards may be portrait, square-ish, folded, or photographed at an angle.

7. Scanner controller

This is the brain of the scanner.

Create:

scanner_controller.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

import '../models/card_corners.dart';
import '../models/detected_card.dart';
import '../models/scanner_state.dart';

class ScannerController extends ChangeNotifier {
  ScannerState state =
      ScannerState.initializing;

  DetectedCard? detectedCard;

  CameraController? cameraController;

  Timer? captureTimer;

  int stableFrames = 0;

  int requiredStableFrames = 12;

  bool isCapturing = false;

  String message =
      'Starting camera...';

  Future<void> initialize(
      CameraDescription camera) async {

    state =
        ScannerState.initializing;

    notifyListeners();

    cameraController =
        CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {

      await cameraController!.initialize();

      state =
          ScannerState.searching;

      message =
          'Searching for business card...';

      notifyListeners();

      await startImageStream();

    } catch (e) {

      state =
          ScannerState.error;

      message =
          'Unable to start camera';

      notifyListeners();
    }
  }

  Future<void> startImageStream() async {

    if (cameraController == null) {
      return;
    }

    if (cameraController!.value.isStreamingImages) {
      return;
    }

    await cameraController!.startImageStream(
      (CameraImage image) {

        if (isCapturing) {
          return;
        }

        // This is where the native/card
        // detection pipeline receives
        // each camera frame.

        processFrame(image);
      },
    );
  }

  Future<void> processFrame(
      CameraImage image) async {

    /*
     * IMPORTANT:
     *
     * Do NOT perform expensive image
     * processing on every frame directly
     * on the UI thread.
     *
     * Production implementation:
     *
     * CameraImage
     *       ↓
     * Frame throttling
     *       ↓
     * Native/OpenCV detector
     *       ↓
     * DetectedCard
     */

    final DetectedCard? result =
        await detectCard(image);

    if (result == null) {

      detectedCard = null;

      stableFrames = 0;

      state =
          ScannerState.searching;

      message =
          'Move camera towards the card';

      notifyListeners();

      return;
    }

    detectedCard = result;

    state =
        ScannerState.detected;

    message =
        'Card detected';

    notifyListeners();

    if (!result.isGoodQuality) {

      state =
          ScannerState.adjusting;

      message =
          'Move closer and align the card';

      stableFrames = 0;

      notifyListeners();

      return;
    }

    final bool stable =
        checkCardStability(result);

    if (!stable) {

      state =
          ScannerState.adjusting;

      message =
          'Hold steady...';

      notifyListeners();

      return;
    }

    stableFrames++;

    state =
        ScannerState.stable;

    message =
        'Hold steady ${requiredStableFrames - stableFrames}';

    notifyListeners();

    if (stableFrames >=
        requiredStableFrames) {

      await autoCapture();
    }
  }

  Future<DetectedCard?> detectCard(
      CameraImage image) async {

    /*
     * Replace this method with the
     * actual native detector.
     *
     * Detection pipeline:
     *
     * YUV camera frame
     *       ↓
     * grayscale
     *       ↓
     * blur
     *       ↓
     * edge detection
     *       ↓
     * contours
     *       ↓
     * polygon approximation
     *       ↓
     * four corners
     */

    return null;
  }

  bool checkCardStability(
      DetectedCard current) {

    /*
     * Production version compares:
     *
     * previous corners
     *        vs
     * current corners
     *
     * If movement is below threshold,
     * card is considered stable.
     */

    return true;
  }

  Future<void> autoCapture() async {

    if (isCapturing) {
      return;
    }

    isCapturing = true;

    state =
        ScannerState.capturing;

    message =
        'Capturing...';

    notifyListeners();

    try {

      if (cameraController!
          .value
          .isStreamingImages) {

        await cameraController!
            .stopImageStream();
      }

      final XFile photo =
          await cameraController!
              .takePicture();

      state =
          ScannerState.processing;

      message =
          'Processing card...';

      notifyListeners();

      /*
       * Next:
       *
       * photo
       *   ↓
       * perspective correction
       *   ↓
       * crop
       *   ↓
       * enhance
       *   ↓
       * OCR
       */

      await processCapturedImage(photo);

    } catch (e) {

      state =
          ScannerState.error;

      message =
          'Capture failed';

      notifyListeners();

    } finally {

      isCapturing = false;
    }
  }

  Future<void> processCapturedImage(
      XFile photo) async {

    /*
     * Connect image processing here.
     */

    await Future.delayed(
      const Duration(
        milliseconds: 500,
      ),
    );

    state =
        ScannerState.completed;

    message =
        'Scan completed';

    notifyListeners();
  }

  @override
  void dispose() {

    captureTimer?.cancel();

    cameraController?.dispose();

    super.dispose();
  }
}

Important: I deliberately did not pretend that a few Dart lines magically implement reliable four-corner detection. The detectCard() function is the boundary where the actual native/OpenCV detector belongs.

8. Camera screen

Create:

business_card_scanner_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../controllers/scanner_controller.dart';
import '../widgets/scanner_overlay.dart';

class BusinessCardScannerScreen
    extends StatefulWidget {

  final CameraDescription camera;

  const BusinessCardScannerScreen({
    super.key,
    required this.camera,
  });

  @override
  State<BusinessCardScannerScreen>
      createState() =>
          _BusinessCardScannerScreenState();
}

class _BusinessCardScannerScreenState
    extends State<BusinessCardScannerScreen> {

  late final ScannerController controller;

  @override
  void initState() {

    super.initState();

    controller =
        ScannerController();

    controller.initialize(
      widget.camera,
    );

    controller.addListener(
      _onScannerChanged,
    );
  }

  void _onScannerChanged() {

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  @override
  Widget build(
      BuildContext context) {

    final camera =
        controller.cameraController;

    if (camera == null ||
        !camera.value.isInitialized) {

      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,

      body: Stack(
        fit: StackFit.expand,
        children: [

          CameraPreview(camera),

          ScannerOverlay(
            detectedCard:
                controller.detectedCard,
            message:
                controller.message,
          ),

          _topBar(),

          _bottomControls(),
        ],
      ),
    );
  }

  Widget _topBar() {

    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),

        child: Row(
          children: [

            _circleButton(
              Icons.arrow_back,
              () {
                Navigator.pop(context);
              },
            ),

            const Spacer(),

            const Text(
              'Scan Business Card',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const Spacer(),

            _circleButton(
              Icons.flash_auto,
              () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomControls() {

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,

      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(24),

          child: Column(
            children: [

              Text(
                controller.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 18),

              Container(
                width: 72,
                height: 72,

                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 4,
                  ),
                ),

                child: const Center(
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleButton(
    IconData icon,
    VoidCallback onTap,
  ) {

    return InkWell(
      onTap: onTap,

      borderRadius:
          BorderRadius.circular(30),

      child: Container(
        width: 42,
        height: 42,

        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),

        child: Icon(
          icon,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  void dispose() {

    controller
        .removeListener(
      _onScannerChanged,
    );

    controller.dispose();

    super.dispose();
  }
}
9. Actual detected-card overlay

This is what gives you the dynamic green four-corner shape.

Create:

scanner_overlay.dart

import 'package:flutter/material.dart';

import '../models/detected_card.dart';

class ScannerOverlay
    extends StatelessWidget {

  final DetectedCard? detectedCard;

  final String message;

  const ScannerOverlay({
    super.key,
    required this.detectedCard,
    required this.message,
  });

  @override
  Widget build(
      BuildContext context) {

    return IgnorePointer(
      child: CustomPaint(
        painter: ScannerPainter(
          detectedCard:
              detectedCard,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class ScannerPainter
    extends CustomPainter {

  final DetectedCard? detectedCard;

  ScannerPainter({
    required this.detectedCard,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {

    if (detectedCard == null) {

      _drawSearchingFrame(
        canvas,
        size,
      );

      return;
    }

    final points =
        detectedCard!.corners.points;

    final path = Path();

    path.moveTo(
      points[0].dx,
      points[0].dy,
    );

    for (
      int i = 1;
      i < points.length;
      i++
    ) {

      path.lineTo(
        points[i].dx,
        points[i].dy,
      );
    }

    path.close();

    final bool good =
        detectedCard!.isGoodQuality;

    final paint =
        Paint()
          ..color = good
              ? Colors.greenAccent
              : Colors.orangeAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;

    canvas.drawPath(
      path,
      paint,
    );

    for (final point in points) {

      canvas.drawCircle(
        point,
        7,
        Paint()
          ..color = good
              ? Colors.greenAccent
              : Colors.orangeAccent,
      );
    }
  }

  void _drawSearchingFrame(
    Canvas canvas,
    Size size,
  ) {

    final width =
        size.width * .82;

    final height =
        width / 1.586;

    final rect =
        Rect.fromCenter(
      center: Offset(
        size.width / 2,
        size.height / 2,
      ),
      width: width,
      height: height,
    );

    final paint =
        Paint()
          ..color = Colors.white70
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(16),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(
      covariant ScannerPainter oldDelegate) {

    return oldDelegate.detectedCard !=
        detectedCard;
  }
}

Now the UI can change from:

Searching

┌──────────────────┐
│                  │
│                  │
└──────────────────┘

to:

Card detected

       ●────────●
      ╱          ╲
     │   CARD     │
      ╲          ╱
       ●────────●

       GREEN
10. Main entry point

main.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'features/business_card_scanner/screens/business_card_scanner_screen.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  final cameras =
      await availableCameras();

  final rearCamera =
      cameras.firstWhere(
    (camera) =>
        camera.lensDirection ==
        CameraLensDirection.back,
  );

  runApp(
    MyApp(
      camera: rearCamera,
    ),
  );
}

class MyApp extends StatelessWidget {

  final CameraDescription camera;

  const MyApp({
    super.key,
    required this.camera,
  });

  @override
  Widget build(
      BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner:
          false,

      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),

      home:
          BusinessCardScannerScreen(
        camera: camera,
      ),
    );
  }
}
11. Android permission

In:

android/app/src/main/AndroidManifest.xml

add:

<uses-permission
    android:name="android.permission.CAMERA"/>

The current camera plugin documentation also requires camera permissions/configuration on Android and iOS.

For iOS:

ios/Runner/Info.plist

add:

<key>NSCameraUsageDescription</key>
<string>
We use the camera to scan business cards.
</string>
12. But where does actual 4-corner detection happen?

This is the critical part.

Your complete production pipeline should be:

CameraImage
    │
    ▼
Frame Throttle
    │
    ▼
YUV → Gray
    │
    ▼
Gaussian Blur
    │
    ▼
Canny
    │
    ▼
Contours
    │
    ▼
Polygon Approximation
    │
    ▼
Find Quadrilateral
    │
    ▼
Area Check
    │
    ▼
Aspect Ratio Check
    │
    ▼
Corner Ordering
    │
    ▼
Perspective Check
    │
    ▼
Blur Check
    │
    ▼
Stability Check
    │
    ▼
DetectedCard

This is the part I would not implement as heavy Dart code running on every camera frame.

The camera package can stream frames to Dart, but continuous computer-vision processing is exactly where you want optimized native processing.

13. Automatic stability detection

Suppose frame 1 detects:

TL = (100,200)
TR = (700,190)
BR = (710,520)
BL = (95,530)

Frame 2:

TL = (102,201)
TR = (702,191)
BR = (711,521)
BL = (97,531)

Frame 3:

TL = (101,201)
TR = (701,191)
BR = (710,520)
BL = (96,530)

Movement is tiny.

Therefore:

Frame 1     detected
Frame 2     stable
Frame 3     stable
Frame 4     stable
...
Frame 12    stable
             ↓
          CAPTURE

But if the user moves the phone:

Frame 1     detected
Frame 2     detected
Frame 3     moved
Frame 4     moved
             ↓
       stableFrames = 0

Then:

"Hold steady..."

again.

14. Perspective correction

This is the next major part.

Suppose the camera sees:

       ╱──────────────╲
      ╱                ╲
     │     BUSINESS     │
     │       CARD       │
      ╲                ╱
       ╲──────────────╱

The four detected points become:

final points = [
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
];

Then transform them to:

0,0 ───────────────── 1200,0
│                       │
│      CARD             │
│                       │
│                       │
0,700 ───────────── 1200,700

Result:

┌─────────────────────────────┐
│                             │
│        BUSINESS CARD        │
│                             │
└─────────────────────────────┘

This dramatically improves OCR.

15. OCR stage

After the image is corrected:

final inputImage =
    InputImage.fromFilePath(
  correctedImagePath,
);

final textRecognizer =
    TextRecognizer(
  script:
      TextRecognitionScript.latin,
);

final recognizedText =
    await textRecognizer.processImage(
  inputImage,
);

Then parse:

John Smith
Business Development Manager
ABC Technologies

+91 9876543210
john@abc.com
www.abc.com

into:

class ContactData {

  final String name;

  final String company;

  final String designation;

  final String phone;

  final String email;

  final String website;

  final String address;

  ContactData({
    required this.name,
    required this.company,
    required this.designation,
    required this.phone,
    required this.email,
    required this.website,
    required this.address,
  });
}
16. Final UX

Your actual SmartCards screen should therefore behave like this:

STEP 1

Camera opens

"Point camera at business card"

↓

STEP 2

Card not detected

"Searching..."

↓

STEP 3

Card detected

╭──────────────────╮
│                  │
│   BUSINESS CARD  │
│                  │
╰──────────────────╯

✓ Card detected

↓

STEP 4

Card is too far

"Move closer"

↓

STEP 5

Card is tilted

"Align card"

↓

STEP 6

Everything good

╭──────────────────╮
│                  │
│   BUSINESS CARD  │
│                  │
╰──────────────────╯

✓ Perfect
Hold steady...

↓

STEP 7

Automatic capture

3
2
1

CAPTURED ✓

↓

STEP 8

Processing

Crop
 ↓
Perspective correction
 ↓
Enhancement
 ↓
OCR

↓

STEP 9

CONTACT FOUND

John Smith

ABC Technologies

+91 9876543210

john@abc.com

www.abc.com

↓

STEP 10

EDIT CONTACT

[ Name             ]
[ Company          ]
[ Designation      ]
[ Phone             ]
[ Email             ]
[ Website           ]

       SAVE CONTACT
One important recommendation

For your first Flutter prototype, I would not start by writing hundreds of lines of custom OpenCV code.

Build it in two phases:

Phase 1 — prove the UX

Use ML Kit's document scanner on Android. It already supports automatic capture, document/edge detection, cropping and rotation.

Phase 2 — SmartCards custom scanner

Then replace that scanner with:

Flutter Camera
       +
Native OpenCV detector
       +
Custom Flutter overlay
       +
Stability engine
       +
Perspective correction
       +
OCR
       +
Contact parser

That gives you the exact custom UI in the generated sample image, rather than being locked into Google's scanner UI.

Also note: the current ML Kit document-scanner Flutter package is Android-only, so it should not be your final solution if your SmartCards scanner must have the same custom behavior on both Android and iOS.