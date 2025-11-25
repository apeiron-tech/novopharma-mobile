import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import '../models/blog_post.dart';
import '../theme.dart';
import '../widgets/video_player_dialog.dart';

class ActualiteDetailsScreen extends StatefulWidget {
  final BlogPost actualite;

  const ActualiteDetailsScreen({super.key, required this.actualite});

  @override
  State<ActualiteDetailsScreen> createState() => _ActualiteDetailsScreenState();
}

class _ActualiteDetailsScreenState extends State<ActualiteDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              LightModeColors.novoPharmaBlue,
              LightModeColors.novoPharmaBlue.withValues(alpha: 0.8),
              Colors.white,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(child: _buildContent(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actualité',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
                Text(
                  widget.actualite.actualiteCategory ?? 'Actualité',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image
              if (widget.actualite.coverImageUrl != null &&
                  widget.actualite.coverImageUrl!.isNotEmpty)
                Container(
                  height: 250,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: widget.actualite.coverImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[100],
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: LightModeColors.novoPharmaBlue,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[100],
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey[400],
                        size: 60,
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Badge
                    if (widget.actualite.actualiteCategory != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              LightModeColors.novoPharmaBlue.withValues(
                                alpha: 0.1,
                              ),
                              LightModeColors.novoPharmaBlue.withValues(
                                alpha: 0.05,
                              ),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: LightModeColors.novoPharmaBlue.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        child: Text(
                          widget.actualite.actualiteCategory!,
                          style: const TextStyle(
                            color: LightModeColors.novoPharmaBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Title
                    Text(
                      widget.actualite.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Meta Information
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: LightModeColors.novoPharmaBlue.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person_outline,
                            size: 16,
                            color: LightModeColors.novoPharmaBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.actualite.author ?? 'Admin',
                          style: const TextStyle(
                            fontSize: 14,
                            color: LightModeColors.novoPharmaBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(widget.actualite.createdAt),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Excerpt
                    if (widget.actualite.excerpt != null &&
                        widget.actualite.excerpt!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: LightModeColors.novoPharmaBlue.withValues(
                            alpha: 0.05,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: LightModeColors.novoPharmaBlue.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                        child: Text(
                          widget.actualite.excerpt!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            height: 1.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                    if (widget.actualite.excerpt != null &&
                        widget.actualite.excerpt!.isNotEmpty)
                      const SizedBox(height: 24),

                    // Content
                    Text(
                      widget.actualite.content,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Media Section
                    if (widget.actualite.media.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fichiers & Médias',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...widget.actualite.media.map((mediaFile) {
                            return _buildMediaItem(mediaFile);
                          }).toList(),
                        ],
                      ),

                    if (widget.actualite.media.isNotEmpty)
                      const SizedBox(height: 24),

                    // Tags
                    if (widget.actualite.tags.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tags',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.actualite.tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaItem(dynamic mediaFile) {
    // Handle different media file formats
    String fileName = '';
    String fileUrl = '';
    String fileType = '';
    int fileSize = 0;
    bool isVideo = false;
    bool isPdf = false;
    bool isImage = false;

    if (mediaFile is Map<String, dynamic>) {
      fileName = mediaFile['name'] ?? 'Fichier sans nom';
      fileUrl = mediaFile['url'] ?? '';
      fileType = mediaFile['type'] ?? '';
      fileSize = mediaFile['size'] ?? 0;
    } else if (mediaFile.runtimeType.toString().contains('MediaFile')) {
      fileName = mediaFile.name ?? 'Fichier sans nom';
      fileUrl = mediaFile.url ?? '';
      fileType = mediaFile.type ?? '';
      fileSize = mediaFile.size ?? 0;
      isVideo = mediaFile.isVideo ?? false;
      isPdf = mediaFile.isPdf ?? false;
      isImage = mediaFile.isImage ?? false;
    }

    // Determine file type if not explicitly set
    if (fileType.isEmpty) {
      final extension = fileName.toLowerCase().split('.').last;
      switch (extension) {
        case 'mp4':
        case 'mov':
        case 'avi':
        case 'mkv':
          isVideo = true;
          fileType = 'video';
          break;
        case 'pdf':
          isPdf = true;
          fileType = 'pdf';
          break;
        case 'jpg':
        case 'jpeg':
        case 'png':
        case 'gif':
          isImage = true;
          fileType = 'image';
          break;
        default:
          fileType = 'document';
      }
    } else {
      isVideo = fileType.toLowerCase().contains('video');
      isPdf = fileType.toLowerCase().contains('pdf');
      isImage = fileType.toLowerCase().contains('image');
    }

    IconData iconData;
    Color iconColor;

    if (isVideo) {
      iconData = Icons.play_circle_filled;
      iconColor = Colors.red[600]!;
    } else if (isPdf) {
      iconData = Icons.picture_as_pdf;
      iconColor = Colors.red[700]!;
    } else if (isImage) {
      iconData = Icons.image;
      iconColor = Colors.blue[600]!;
    } else {
      iconData = Icons.insert_drive_file;
      iconColor = Colors.grey[600]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () =>
              _handleMediaTap(fileUrl, fileName, isVideo, isPdf, isImage),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(iconData, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              fileType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: iconColor,
                              ),
                            ),
                          ),
                          if (fileSize > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              _formatFileSize(fileSize),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  isVideo ? Icons.play_arrow : Icons.download,
                  color: iconColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleMediaTap(
    String url,
    String fileName,
    bool isVideo,
    bool isPdf,
    bool isImage,
  ) async {
    if (url.isEmpty) {
      _showSnackBar('URL du fichier non disponible');
      return;
    }

    try {
      if (isVideo) {
        // Play video in custom player
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => VideoPlayerDialog(
            videoUrl: url,
            videoTitle: fileName,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      } else if (isImage) {
        // Show image in full-screen viewer
        await _showImageViewer(url, fileName);
      } else {
        // For PDFs and other documents, copy URL to clipboard and show message
        await _handleDocumentFile(url, fileName, isPdf);
      }
    } catch (e) {
      _showSnackBar('Erreur lors de l\'ouverture du fichier: $e');
    }
  }

  Future<void> _showImageViewer(String imageUrl, String imageName) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            PhotoView(
              imageProvider: CachedNetworkImageProvider(imageUrl),
              backgroundDecoration: const BoxDecoration(
                color: Colors.black,
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2.0,
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  imageName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDocumentFile(String url, String fileName, bool isPdf) async {
    try {
      // Show dialog with options
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(isPdf ? 'Document PDF' : 'Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Fichier: $fileName'),
              const SizedBox(height: 16),
              const Text(
                'Sélectionnez une option pour ouvrir le document:',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _copyUrlToClipboard(url);
              },
              child: const Text('Copier le lien'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _openInBrowser(url);
              },
              child: const Text('Ouvrir'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnackBar('Erreur lors de l\'ouverture du document: $e');
    }
  }

  Future<void> _copyUrlToClipboard(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      _showSnackBar('Lien copié dans le presse-papiers');
    } catch (e) {
      _showSnackBar('Erreur lors de la copie: $e');
    }
  }

  Future<void> _openInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        await _copyUrlToClipboard(url);
        _showSnackBar('Impossible d\'ouvrir automatiquement. Lien copié dans le presse-papiers.');
      }
    } catch (e) {
      await _copyUrlToClipboard(url);
      _showSnackBar('Erreur d\'ouverture. Lien copié dans le presse-papiers.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: LightModeColors.novoPharmaBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String _formatDate(DateTime date) {
    final months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
