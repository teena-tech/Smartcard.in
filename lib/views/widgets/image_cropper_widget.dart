import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class ImageCropperHelper {
  static List<PlatformUiSettings> _buildUiSettings({
    required BuildContext? context,
    required String title,
    required CropAspectRatioPreset aspectRatioPreset,
    bool lockAspectRatio = true,
    bool useWebSettings = false,
    CropStyle cropStyle = CropStyle.rectangle,
  }) {
    final uiSettings = <PlatformUiSettings>[
      AndroidUiSettings(
        toolbarTitle: title,
        toolbarColor: AppColors.primaryRed,
        toolbarWidgetColor: Colors.white,
        initAspectRatio: aspectRatioPreset,
        lockAspectRatio: lockAspectRatio,
        statusBarColor: AppColors.primaryRed,
        hideBottomControls: true, 
        cropStyle: cropStyle,
        cropFrameColor: AppColors.primaryRed,
        cropGridColor: AppColors.primaryRed.withValues(alpha: 0.5),
        activeControlsWidgetColor: AppColors.primaryRed,
      ),
      IOSUiSettings(
        title: title,
        aspectRatioLockEnabled: lockAspectRatio,
        resetButtonHidden: false,
        aspectRatioPickerButtonHidden: true, // Hides ratio picker on iOS
      ),
    ];

    if (kIsWeb && context != null) {
      final size = MediaQuery.of(context).size;
      // Use 80% width and 50% height on smaller screens to absolutely guarantee it fits
      final cropWidth = size.width < 500 ? (size.width * 0.8).toInt() : 400;
      final cropHeight = size.height < 800 ? (size.height * 0.5).toInt() : 400;
      
      uiSettings.add(
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: CropperSize(width: cropWidth, height: cropHeight),
          dragMode: WebDragMode.crop,
          viewwMode: WebViewMode.mode_1,
        ),
      );
    }

    return uiSettings;
  }

  static Future<CroppedFile?> cropProfileImage(
    String imagePath, {
    BuildContext? context,
  }) async {
    return await ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: _buildUiSettings(
        context: context,
        title: 'Crop Profile Photo',
        aspectRatioPreset: CropAspectRatioPreset.square,
        lockAspectRatio: false, // Set to false to allow manual frame adjustment
        cropStyle: CropStyle.circle,
      ),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
  }

  static Future<CroppedFile?> cropCompanyLogo(
    String imagePath, {
    BuildContext? context,
  }) async {
    return await ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: _buildUiSettings(
        context: context,
        title: 'Crop Company Logo',
        aspectRatioPreset: CropAspectRatioPreset.square, // Starts as square
        lockAspectRatio: false, // Set to false to allow manual frame adjustment
        cropStyle: CropStyle.rectangle,
      ),
      compressFormat: ImageCompressFormat.png,
      compressQuality: 90,
      maxWidth: 512,
      maxHeight: 512,
    );
  }

  static Future<CroppedFile?> cropBackgroundImage(
    String imagePath, {
    BuildContext? context,
    double aspectRatio = 16 / 9,
  }) async {
    return await ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: _buildUiSettings(
        context: context,
        title: 'Customize Background',
        aspectRatioPreset: CropAspectRatioPreset.original, // Flexible
        lockAspectRatio: false, // Flexible
        useWebSettings: true,
        cropStyle: CropStyle.rectangle,
      ),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      maxWidth: 1600,
      maxHeight: 900,
    );
  }
}

class ImagePickerAndCropperWidget extends StatefulWidget {
  final String title;
  final String cropType; // 'profile', 'logo', 'background'
  final ValueChanged<String> onImageCropped;
  final dynamic colors;
  final String? initialImagePath;

  const ImagePickerAndCropperWidget({
    super.key,
    required this.title,
    required this.cropType,
    required this.onImageCropped,
    required this.colors,
    this.initialImagePath,
  });

  @override
  State<ImagePickerAndCropperWidget> createState() =>
      _ImagePickerAndCropperWidgetState();
}

class _ImagePickerAndCropperWidgetState
    extends State<ImagePickerAndCropperWidget> {
  String? _croppedImagePath;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _croppedImagePath = widget.initialImagePath;
  }

  Future<void> _pickAndCropImage({bool fromCamera = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // Step 1: Pick image (with compression to prevent OOM crashes)
      final XFile? picked = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (picked == null) {
        // User cancelled — not an error
        if (context.mounted) setState(() => _isLoading = false);
        return;
      }

      // Step 2: Crop the picked image
      await _cropImage(picked.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cropImage(String imagePath) async {
    try {
      CroppedFile? croppedFile;

      switch (widget.cropType) {
        case 'profile':
          croppedFile =
              await ImageCropperHelper.cropProfileImage(imagePath, context: context);
          break;
        case 'logo':
          croppedFile =
              await ImageCropperHelper.cropCompanyLogo(imagePath, context: context);
          break;
        case 'background':
          croppedFile = await ImageCropperHelper.cropBackgroundImage(
            imagePath,
            context: context,
          );
          break;
        default:
          croppedFile =
              await ImageCropperHelper.cropProfileImage(imagePath, context: context);
      }

      if (croppedFile != null && context.mounted) {
        setState(() => _croppedImagePath = croppedFile!.path);
        widget.onImageCropped(croppedFile.path);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.title} cropped successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cropping image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (context.mounted) setState(() => _isLoading = false);
    }
  }

  void _showPickerSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFEBEB),
                  child: Icon(Icons.camera_alt_outlined, color: AppColors.primaryRed),
                ),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndCropImage(fromCamera: true);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFEBEB),
                  child: Icon(Icons.photo_library_outlined, color: AppColors.primaryRed),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndCropImage(fromCamera: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors?.border ?? Colors.grey.withValues(alpha: 0.15),
          width: 1.5,
        ),
        color: colors?.card ?? Colors.white,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors?.text ?? Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          if (_croppedImagePath != null) ...[
            Center(
              child: ClipRRect(
                borderRadius: widget.cropType == 'profile'
                    ? BorderRadius.circular(100)
                    : BorderRadius.circular(8),
                child: kIsWeb
                    ? Image.network(
                        _croppedImagePath!,
                        width: widget.cropType == 'profile' ? 120 : double.infinity,
                        height: widget.cropType == 'background' ? 150 : 120,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(_croppedImagePath!),
                        width: widget.cropType == 'profile' ? 120 : double.infinity,
                        height: widget.cropType == 'background' ? 150 : 120,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _showPickerSourceSheet(),
                  icon: const Icon(Icons.image),
                  label: Text(_croppedImagePath == null ? 'Pick Image' : 'Change Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_croppedImagePath != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () {
                    setState(() => _croppedImagePath = null);
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ],
          ),
          if (_isLoading) ...[
            const SizedBox(height: 12),
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryRed,
              ),
            ),
          ],
          if (_croppedImagePath != null) ...[
            const SizedBox(height: 8),
            Text(
              'Dimensions: ${widget.cropType == 'background' ? '1920x1080 or custom' : '512x512'} (Square)',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: colors?.muted ?? Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

