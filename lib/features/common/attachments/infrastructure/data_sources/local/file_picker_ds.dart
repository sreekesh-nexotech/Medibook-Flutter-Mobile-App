import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart' hide PickedFile;

import '../../../domain/entities/stored_file.dart';
import '../../../domain/entities/upload_policy.dart';
import '../../../domain/repositories/file_upload_service.dart';

/// The device-side data source: the platform file and image pickers.
///
/// "Local" in the four-layer sense — it touches the device, not the network
/// — and it is the only file in the app that imports `file_picker` or
/// `image_picker`. It returns a [PickedFile] whose MIME type is already
/// resolved, or null when the user backed out.
abstract interface class FilePickerDataSource {
  Future<PickedFile?> pick(FileUploadPurpose purpose, PickSource source);
}

class PlatformFilePickerDataSource implements FilePickerDataSource {
  PlatformFilePickerDataSource({ImagePicker? imagePicker})
    : _images = imagePicker ?? ImagePicker();

  final ImagePicker _images;

  @override
  Future<PickedFile?> pick(FileUploadPurpose purpose, PickSource source) {
    switch (source) {
      case PickSource.files:
        return _pickDocument(purpose);
      case PickSource.gallery:
        return _pickImage(ImageSource.gallery);
      case PickSource.camera:
        return _pickImage(ImageSource.camera);
    }
  }

  Future<PickedFile?> _pickDocument(FileUploadPurpose purpose) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: UploadPolicy.allowedExtensions(purpose),
    );
    if (files.isEmpty) return null;
    final file = files.first;
    final size = file.lengthSync() ?? await file.length() ?? 0;
    return PickedFile(
      name: file.name,
      // An unknown extension is passed through as an empty MIME so the
      // policy check rejects it with the right message.
      mime: UploadPolicy.mimeFor(file.name) ?? '',
      sizeBytes: size,
      path: file.path,
      readBytes: file.readAsBytes,
    );
  }

  Future<PickedFile?> _pickImage(ImageSource source) async {
    final image = await _images.pickImage(source: source);
    if (image == null) return null;
    final size = await image.length();
    return PickedFile(
      name: image.name,
      mime: UploadPolicy.mimeFor(image.name, hint: image.mimeType) ?? '',
      sizeBytes: size,
      path: image.path,
      readBytes: image.readAsBytes,
    );
  }
}
