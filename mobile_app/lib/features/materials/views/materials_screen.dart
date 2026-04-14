import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class MaterialsScreen extends ConsumerStatefulWidget {
  const MaterialsScreen({super.key});

  @override
  ConsumerState<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends ConsumerState<MaterialsScreen> {
  List<dynamic> materials = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    try {
      final response = await ref.read(dioProvider).get('/materials/');
      setState(() {
        materials = response.data as List<dynamic>;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Materials')),
      body: error != null
          ? Center(child: Text(error!))
          : ListView.builder(
              itemCount: materials.length,
              itemBuilder: (context, index) {
                final item = materials[index] as Map<String, dynamic>;
                return Card(
                  child: ListTile(
                    title: Text(item['title'] as String),
                    subtitle: Text(item['subject'] as String),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Open URL: ${item['pdf_url']}')),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
