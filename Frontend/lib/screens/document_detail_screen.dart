import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models/study_document.dart';
import '../providers/study_provider.dart';
import 'chat_screen.dart';

class DocumentDetailScreen extends StatefulWidget {
  final StudyDocument document;

  const DocumentDetailScreen({super.key, required this.document});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late StudyDocument _doc;

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
  }

  Future<void> _generateExplanation() async {
    final provider = context.read<StudyProvider>();
    final summary = await provider.explainDocument(_doc.id);
    if (summary != null && mounted) {
      setState(() {
        _doc = provider.documents.firstWhere((d) => d.id == _doc.id, orElse: () => _doc);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Study Guide generated successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Chat with this document',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    title: _doc.title,
                    documentId: _doc.id,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // File info card
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _doc.fileType,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_doc.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          '${_doc.formattedFileSize} • ${_doc.pageCount} ${_doc.pageCount == 1 ? 'page' : 'pages'}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons: Explain & Chat
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: provider.isLoading ? null : _generateExplanation,
                  icon: provider.isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_doc.summary.isEmpty ? 'Explain Document' : 'Regenerate Study Guide'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        title: _doc.title,
                        documentId: _doc.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Ask Q&A'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // AI Study Explanation section
          if (_doc.summary.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.psychology_outlined, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text('AI Study Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Chip(
                  label: Text(provider.selectedProvider.toUpperCase(), style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: MarkdownBody(
                data: _doc.summary,
                selectable: true,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Extracted Text Preview section
          ExpansionTile(
            title: const Text('Extracted Document Text Preview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            leading: const Icon(Icons.text_snippet_outlined),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _doc.extractedText ?? _doc.extractedTextPreview,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
