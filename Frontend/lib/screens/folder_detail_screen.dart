import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../models/study_folder.dart';
import '../providers/study_provider.dart';
import 'chat_screen.dart';
import 'document_detail_screen.dart';

class FolderDetailScreen extends StatefulWidget {
  final StudyFolder folder;

  const FolderDetailScreen({super.key, required this.folder});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudyProvider>().fetchDocuments(folderId: widget.folder.id);
    });
  }

  Future<void> _pickAndUploadFiles() async {
    final pickedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md', 'markdown', 'csv', 'json', 'py', 'dart'],
    );

    if (pickedFiles.isNotEmpty && mounted) {
      final success = await context.read<StudyProvider>().uploadFiles(
        pickedFiles,
        folderId: widget.folder.id,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded ${pickedFiles.length} document(s) to folder!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudyProvider>();
    final folderDocs = provider.documents.where((d) => d.folderId == widget.folder.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        actions: [
          IconButton(
            tooltip: 'Upload files to folder',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: _pickAndUploadFiles,
          ),
          IconButton(
            tooltip: 'Chat with entire folder',
            icon: const Icon(Icons.chat_outlined),
            onPressed: folderDocs.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          title: widget.folder.name,
                          folderId: widget.folder.id,
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          // Folder header banner
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: Row(
              children: [
                Icon(Icons.folder_special, size: 40, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.folder.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (widget.folder.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(widget.folder.description, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${folderDocs.length} ${folderDocs.length == 1 ? 'document' : 'documents'} loaded',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: folderDocs.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                title: widget.folder.name,
                                folderId: widget.folder.id,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.psychology, size: 18),
                  label: const Text('Ask Folder'),
                ),
              ],
            ),
          ),

          // Document list in this folder
          Expanded(
            child: folderDocs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.note_add_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text('No documents in this folder yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text('Upload PDFs or text notes to ask questions across them.', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _pickAndUploadFiles,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Documents'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: folderDocs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = folderDocs[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text(doc.fileType, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${doc.formattedFileSize} • ${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DocumentDetailScreen(document: doc),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndUploadFiles,
        icon: const Icon(Icons.add),
        label: const Text('Add Files'),
      ),
    );
  }
}
