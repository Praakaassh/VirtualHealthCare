import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class UploadFileItem {
  final File file;
  double progress;
  bool isUploading;
  bool isComplete;
  String? error;

  UploadFileItem(this.file)
      : progress = 0,
        isUploading = false,
        isComplete = false;
}

class DocumentUploadPage extends StatefulWidget {
  const DocumentUploadPage({Key? key}) : super(key: key);

  @override
  _DocumentUploadPageState createState() => _DocumentUploadPageState();
}

class _DocumentUploadPageState extends State<DocumentUploadPage> {
  List<UploadFileItem> uploadItems = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Upload Documents',
          style: TextStyle(color: Colors.black87),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Text(
              'Selected Files: ${uploadItems.length}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: uploadItems.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: uploadItems.length,
                    itemBuilder: (context, index) {
                      return _buildFileCard(uploadItems[index]);
                    },
                  ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No files selected',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select files or take photos to upload',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(UploadFileItem item) {
    String fileName = item.file.path.split('/').last;
    Color progressColor = item.isComplete
        ? Colors.green
        : item.error != null
            ? Colors.red
            : Theme.of(context).primaryColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getFileIcon(fileName),
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.error != null)
                        Text(
                          item.error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!item.isComplete && !item.isUploading)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        uploadItems.remove(item);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: item.progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _getStatusText(item),
                  style: TextStyle(
                    fontSize: 12,
                    color: progressColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
              ),
              onPressed: _pickFile,
              icon: const Icon(Icons.file_present),
              label: const Text('Select Files'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
              ),
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
          ),
          if (uploadItems.isNotEmpty && !uploadItems.any((item) => item.isUploading)) ...[
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _startUploads,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Upload All'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    String ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getStatusText(UploadFileItem item) {
    if (item.error != null) return 'Failed';
    if (item.isComplete) return 'Completed';
    if (item.isUploading) return '${(item.progress * 100).toInt()}%';
    return 'Waiting';
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          uploadItems.addAll(
            result.paths.map((path) => UploadFileItem(File(path!))).toList(),
          );
        });
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        setState(() {
          uploadItems.add(UploadFileItem(File(photo.path)));
        });
      }
    } catch (e) {
      _showError('Error taking photo: $e');
    }
  }

  Future<void> _startUploads() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('User not logged in');
      return;
    }

    for (var item in uploadItems) {
      if (!item.isComplete && !item.isUploading) {
        _uploadFile(item, user.uid);
      }
    }
  }

 Future<void> _uploadFile(UploadFileItem item, String userId) async {
  setState(() {
    item.isUploading = true;
    item.error = null;
  });

  try {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_${item.file.path.split('/').last}';

    Reference storageReference = FirebaseStorage.instance
        .ref()
        .child('uploads/$userId/$fileName');

    SettableMetadata metadata = SettableMetadata(
      customMetadata: {'filename': item.file.path.split('/').last},
    );

    UploadTask uploadTask = storageReference.putFile(item.file, metadata);

    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      setState(() {
        item.progress = snapshot.bytesTransferred / snapshot.totalBytes;
      });
    });

    await uploadTask;

    setState(() {
      item.isComplete = true;
      item.isUploading = false;
      item.progress = 1.0;
    });
  } catch (e) {
    setState(() {
      item.error = 'Upload failed';
      item.isUploading = false;
    });
    _showError('Error uploading file: $e');
  }
}


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}