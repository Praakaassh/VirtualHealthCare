import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:photo_view/photo_view.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/Homepage/docupload.dart'; // Import DocumentUploadPage

class DocPage extends StatefulWidget {
  final List<Map<String, String>> documents;

  const DocPage({super.key, this.documents = const []});

  @override
  State<DocPage> createState() => _DocPageState();
}

class _DocPageState extends State<DocPage> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Dio _dio = Dio();
  List<Map<String, String>> _documents = [];
  Map<String, double> _downloadProgress = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDocuments();
  }

  // Check and request permissions based on Android version
  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      print('Android SDK Version: $sdkInt'); // Debug print

      if (sdkInt >= 30) {
        // Android 11 (API 30) and above
        print('Checking MANAGE_EXTERNAL_STORAGE permission...'); // Debug print
        if (await Permission.manageExternalStorage.status.isGranted) {
          print('MANAGE_EXTERNAL_STORAGE already granted'); // Debug print
          return true;
        } else {
          print('Requesting MANAGE_EXTERNAL_STORAGE permission...'); // Debug print
          final status = await Permission.manageExternalStorage.request();
          if (status.isPermanentlyDenied) {
            print('Permission permanently denied, opening settings...'); // Debug print
            await openAppSettings();
            return false;
          }
          return status.isGranted;
        }
      } else {
        // Below Android 11
        print('Checking storage permission...'); // Debug print
        if (await Permission.storage.status.isGranted) {
          print('Storage permission already granted'); // Debug print
          return true;
        } else {
          print('Requesting storage permission...'); // Debug print
          final status = await Permission.storage.request();
          if (status.isPermanentlyDenied) {
            print('Permission permanently denied, opening settings...'); // Debug print
            await openAppSettings();
            return false;
          }
          return status.isGranted;
        }
      }
    }
    return true; // For non-Android platforms
  }

  // Fetch documents from Firebase Storage
  Future<void> _fetchDocuments() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        _showError('User not logged in.');
        setState(() {
          _isLoading = false; // Set loading to false even if there's an error
        });
        return;
      }

      Reference storageReference = _storage.ref().child('uploads/${user.uid}');
      ListResult result = await storageReference.listAll();

      List<Map<String, String>> documents = [];
      for (Reference ref in result.items) {
        String url = await ref.getDownloadURL();
        final metadata = await ref.getMetadata();
        String fileName = metadata.customMetadata?['filename'] ?? ref.name;
        documents.add({
          'url': url,
          'fileName': fileName,
          'contentType': metadata.contentType ?? 'application/octet-stream',
        });
      }

      setState(() {
        _documents = documents;
        _isLoading = false; // Set loading to false after successful fetch
      });
    } catch (e) {
      print('Fetch error: $e');
      _showError('Error fetching documents: $e');
      setState(() {
        _isLoading = false; // Set loading to false even if there's an error
      });
    }
  }

  // Download a document
  Future<void> _downloadDocument(String url, String fileName) async {
    try {
      print('Starting download process...'); // Debug print

      // Request storage permission
      bool hasPermission = await _checkPermissions();
      if (!hasPermission) {
        _showError('Storage permission is required. Please grant permission in app settings.');
        return;
      }

      print('Permissions granted, proceeding with download...'); // Debug print

      // Create the download directory if it doesn't exist
      Directory? directory;
      if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.isGranted) {
          directory = Directory('/storage/emulated/0/Download');
        } else {
          directory = await getExternalStorageDirectory();
        }

        if (!await directory!.exists()) {
          await directory.create(recursive: true);
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        _showError('Could not access download directory');
        return;
      }

      final String filePath = '${directory.path}/$fileName';
      print('Downloading to: $filePath'); // Debug print

      // Show download starting message
      _showMessage('Download started');

      // Download with progress tracking
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress[url] = received / total;
            });
            print('Download progress: ${(received / total * 100).toStringAsFixed(2)}%');
          }
        },
        deleteOnError: true,
      );

      setState(() {
        _downloadProgress.remove(url);
      });

      print('Download completed: $filePath');
      _showMessage('File downloaded successfully to Downloads folder');
    } catch (e) {
      print('Download error: $e');
      setState(() {
        _downloadProgress.remove(url);
      });
      _showError('Download failed: $e');
    }
  }

  // Preview a document
  Future<void> _previewDocument(String url, String fileName, String contentType) async {
    try {
      print('Preview started for: $fileName');

      // Get temporary directory for preview
      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/$fileName';
      final File file = File(filePath);

      // Download file for preview if it doesn't exist
      if (!await file.exists()) {
        setState(() {
          _downloadProgress[url] = 0;
        });

        print('Downloading for preview to: $filePath');

        await _dio.download(
          url,
          filePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              setState(() {
                _downloadProgress[url] = received / total;
              });
            }
          },
        );

        setState(() {
          _downloadProgress.remove(url);
        });
      }

      print('Content type: $contentType');

      // Preview based on content type
      if (contentType.contains('pdf')) {
        _navigateToPdfView(filePath);
      } else if (contentType.contains('image')) {
        _navigateToImageView(filePath);
      } else {
        _showError('Preview not supported for this file type: $contentType');
      }
    } catch (e) {
      print('Preview error: $e');
      setState(() {
        _downloadProgress.remove(url);
      });
      _showError('Preview failed: $e');
    }
  }

  // Navigate to PDF preview
  void _navigateToPdfView(String filePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('PDF Preview'),
          ),
          body: PDFView(
            filePath: filePath,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: false,
            pageFling: false,
            onError: (error) {
              print('PDF View Error: $error');
              _showError('Error loading PDF: $error');
            },
          ),
        ),
      ),
    );
  }

  // Navigate to image preview
  void _navigateToImageView(String filePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Image Preview'),
          ),
          body: PhotoView(
            imageProvider: FileImage(File(filePath)),
            errorBuilder: (context, error, stackTrace) {
              print('Image View Error: $error');
              return Center(child: Text('Error loading image: $error'));
            },
          ),
        ),
      ),
    );
  }

  // Show error message
  void _showError(String message) {
    print('Error: $message');
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Show success message
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _initializeDocuments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.documents.isEmpty) {
        await _fetchDocuments();
      } else {
        setState(() {
          _documents = widget.documents;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Initialization error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Matches the light grey background
      body: _isLoading
          ? _buildLoadingState()
          : _documents.isEmpty
          ? _buildEmptyState()
          : _buildDocumentsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navigate to DocumentUploadPage and wait for it to return
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DocumentUploadPage(),
            ),
          );
          // Refresh the document list after returning
          await _fetchDocuments();
        },
        backgroundColor: Colors.blue[600], // Matches the blue from the UI
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 30,
        ),
        tooltip: 'Add Document',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No documents yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload your first document to get started',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading your documents...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList() {
    return RefreshIndicator(
      onRefresh: _fetchDocuments,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView.builder(
          itemCount: _documents.length,
          itemBuilder: (context, index) {
            return _buildDocumentItem(_documents[index]);
          },
        ),
      ),
    );
  }

  // Build a list item for each document
  Widget _buildDocumentItem(Map<String, String> document) {
    String url = document['url']!;
    String fileName = document['fileName']!;
    String contentType = document['contentType']!;
    double? progress = _downloadProgress[url];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getIconColor(contentType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getFileIcon(contentType),
                size: 30,
                color: _getIconColor(contentType),
              ),
            ),
            title: Text(
              fileName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  _getFormattedContentType(contentType),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Progress: ${(progress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            trailing: progress != null
                ? SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                color: Theme.of(context).primaryColor,
              ),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_red_eye),
                  color: Colors.blue,
                  onPressed: () => _previewDocument(url, fileName, contentType),
                  tooltip: 'Preview',
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  color: Colors.blue[600], // Changed to match the UI's blue theme
                  onPressed: () => _downloadDocument(url, fileName),
                  tooltip: 'Download',
                ),
              ],
            ),
          ),
          if (progress != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getIconColor(String contentType) {
    if (contentType.contains('pdf')) {
      return Colors.red;
    } else if (contentType.contains('image')) {
      return Colors.blue;
    } else if (contentType.contains('word')) {
      return Colors.indigo;
    } else {
      return Colors.grey;
    }
  }

  String _getFormattedContentType(String contentType) {
    if (contentType.contains('pdf')) {
      return 'PDF Document';
    } else if (contentType.contains('image')) {
      return 'Image';
    } else if (contentType.contains('word')) {
      return 'Word Document';
    } else {
      return contentType.split('/').last.toUpperCase();
    }
  }

  // Get file icon based on content type
  IconData _getFileIcon(String contentType) {
    if (contentType.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (contentType.contains('image')) {
      return Icons.image;
    } else if (contentType.contains('word')) {
      return Icons.description;
    } else {
      return Icons.insert_drive_file;
    }
  }
}