import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/study_provider.dart';
import 'folder_detail_screen.dart';
import 'document_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudyProvider>().init();
    });
  }

  void _showNewFolderDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Study Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Folder Name',
                hintText: 'e.g. Biology 101, Machine Learning',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Course notes, exams, chapters...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                final newFolder = await context.read<StudyProvider>().createFolder(name, descCtrl.text.trim());
                if (newFolder != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Folder "${newFolder.name}" created!')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAIProviderDialog() {
    final provider = context.read<StudyProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Select AI Engine'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: provider.aiProviders.length,
            itemBuilder: (context, index) {
              final p = provider.aiProviders[index];
              return RadioListTile<String>(
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p.defaultModel}\n${p.description}', style: const TextStyle(fontSize: 12)),
                isThreeLine: true,
                value: p.id,
                groupValue: provider.selectedProvider,
                secondary: p.isConfigured
                    ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                    : const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                onChanged: (val) {
                  if (val != null) {
                    provider.setSelectedProvider(val, model: p.defaultModel);
                    Navigator.pop(ctx);
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    final provider = context.read<StudyProvider>();
    final urlCtrl = TextEditingController(text: provider.currentBaseUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Connection Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Django backend API base URL:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                hintText: 'http://127.0.0.1:8000/api',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Windows Desktop / Web: http://127.0.0.1:8000/api\n• Android Emulator: http://10.0.2.2:8000/api',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.setBaseUrl(urlCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save & Reconnect'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadFiles() async {
    final provider = context.read<StudyProvider>();
    int? selectedFolderId;

    if (provider.folders.isNotEmpty) {
      selectedFolderId = await showDialog<int?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select Study Destination'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.note_alt_outlined),
                title: const Text('Upload as Standalone File'),
                onTap: () => Navigator.pop(ctx, null),
              ),
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Or add to a Study Folder:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              ...provider.folders.map(
                (f) => ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(f.name),
                  subtitle: Text('${f.totalDocuments} files'),
                  onTap: () => Navigator.pop(ctx, f.id),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pickedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md', 'markdown', 'csv', 'json', 'py', 'dart'],
    );

    if (pickedFiles.isNotEmpty && mounted) {
      final success = await provider.uploadFiles(pickedFiles, folderId: selectedFolderId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully uploaded ${pickedFiles.length} document(s)!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_stories, color: Colors.deepPurple),
            const SizedBox(width: 8),
            const Text('Co-Study', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: provider.isConnected ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 4,
                    backgroundColor: provider.isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    provider.isConnected ? 'Connected' : 'Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: provider.isConnected ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'AI Engine Settings',
            icon: const Icon(Icons.auto_awesome),
            onPressed: _showAIProviderDialog,
          ),
          IconButton(
            tooltip: 'Connection Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.init(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // AI Active Engine Banner
            InkWell(
              onTap: _showAIProviderDialog,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade700, Colors.indigo.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.psychology, color: Colors.white, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active AI Engine', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(
                            provider.selectedProvider.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (provider.selectedModel != null)
                            Text(
                              provider.selectedModel!,
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    const Chip(
                      label: Text('Change', style: TextStyle(fontSize: 12)),
                      backgroundColor: Colors.white24,
                      labelStyle: TextStyle(color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Study Folders Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Study Folders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _showNewFolderDialog,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('New Folder'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (provider.folders.isEmpty)
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.folder_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No study folders yet', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Create folders to organize and ask questions across multiple files.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _showNewFolderDialog,
                        child: const Text('Create Folder'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.folders.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final folder = provider.folders[index];
                    return SizedBox(
                      width: 180,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FolderDetailScreen(folder: folder),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.folder, color: Theme.of(context).colorScheme.primary, size: 32),
                                const Spacer(),
                                Text(
                                  folder.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${folder.totalDocuments} ${folder.totalDocuments == 1 ? 'file' : 'files'}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 28),

            // Recent Documents Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('All Uploaded Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => provider.fetchDocuments(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (provider.documents.isEmpty)
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.upload_file_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No documents uploaded', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Upload PDFs or text files to get AI study notes & answers.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _pickAndUploadFiles,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Files'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.documents.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final doc = provider.documents[index];
                  final hasSummary = doc.summary.isNotEmpty;
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          doc.fileType,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('${doc.formattedFileSize} • ${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          if (hasSummary)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                                  const SizedBox(width: 4),
                                  Text('AI Study Guide Ready', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                        ],
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndUploadFiles,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload Files'),
      ),
    );
  }
}
