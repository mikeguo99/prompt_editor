// Flutter Prompt 编辑器应用，支持 macOS

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const PromptEditorApp());
}

class PromptEditorApp extends StatelessWidget {
  const PromptEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prompt 编辑器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PromptEditorHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PromptEditorHome extends StatefulWidget {
  const PromptEditorHome({super.key});

  @override
  State<PromptEditorHome> createState() => _PromptEditorHomeState();
}

class _PromptEditorHomeState extends State<PromptEditorHome> {
  String? workspacePath;
  String? currentPromptName;
  String template = '';
  final Map<String, String> variables = {};
  final Map<String, TextEditingController> variableControllers = {};
  final TextEditingController templateController = TextEditingController();
  final TextEditingController newVariableController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    templateController.dispose();
    newVariableController.dispose();
    for (var controller in variableControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadWorkspace() async {
    final dir = await getApplicationSupportDirectory();
    final workspaceFile = File('${dir.path}/workspace.txt');
    if (await workspaceFile.exists()) {
      final path = await workspaceFile.readAsString();
      setState(() {
        workspacePath = path;
      });
      _loadPrompts();
    }
  }

  Future<void> _selectWorkspace() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      final dir = await getApplicationSupportDirectory();
      final workspaceFile = File('${dir.path}/workspace.txt');
      await workspaceFile.writeAsString(result);
      setState(() {
        workspacePath = result;
        currentPromptName = null;
        template = '';
        templateController.text = '';
        variables.clear();
        variableControllers.clear();
      });
      _loadPrompts();
    }
  }

  Future<void> _loadPrompts() async {
    if (workspacePath != null) {
      final promptDir = Directory('$workspacePath/prompt');
      if (await promptDir.exists()) {
        final prompts = await promptDir.list().toList();
        if (prompts.isNotEmpty) {
          _loadPrompt(prompts.first.path.split('/').last);
        }
      }
    }
  }

  Future<void> _loadPrompt(String promptName) async {
    if (workspacePath != null) {
      final promptDir = Directory('$workspacePath/prompt/$promptName');
      if (await promptDir.exists()) {
        setState(() {
          currentPromptName = promptName;
          templateController.text = '';
          variables.clear();
          for (var controller in variableControllers.values) {
            controller.dispose();
          }
          variableControllers.clear();
        });

        final templateFile = File('${promptDir.path}/template.md');
        if (await templateFile.exists()) {
          final templateContent = await templateFile.readAsString();
          setState(() {
            template = templateContent;
            templateController.text = templateContent;
          });
        }

        final files = await promptDir.list().toList();
        for (var file in files) {
          if (file is File &&
              file.path.endsWith('.md') &&
              !file.path.endsWith('template.md')) {
            final variableName =
                file.path.split('/').last.replaceAll('.md', '');
            final content = await file.readAsString();
            setState(() {
              variables[variableName] = content;
              variableControllers[variableName] =
                  TextEditingController(text: content);
            });
          }
        }
      }
    }
  }

  Future<void> _createPrompt() async {
    final promptNameController = TextEditingController();
    final promptName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建 Prompt'),
        content: TextField(
          controller: promptNameController,
          decoration: const InputDecoration(
            hintText: '输入名称',
            helperText: '只能包含字母、数字、下划线和连字符',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
              onPressed: () {
                final name = promptNameController.text;
                if (RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(name)) {
                  Navigator.pop(context, name);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('名称格式不正确')),
                  );
                }
              },
              child: const Text('确定')),
        ],
      ),
    );

    if (promptName != null && workspacePath != null) {
      final promptDir = Directory('$workspacePath/prompt/$promptName');
      if (!await promptDir.exists()) {
        await promptDir.create(recursive: true);
        await File('${promptDir.path}/template.md').writeAsString('');
        _loadPrompt(promptName);
      }
    }
  }

  Future<void> _addVariable() async {
    final name = newVariableController.text;
    if (name.isNotEmpty && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(name)) {
      if (workspacePath != null && currentPromptName != null) {
        final promptDir = Directory('$workspacePath/prompt/$currentPromptName');
        final file = File('${promptDir.path}/$name.md');
        await file.writeAsString('');
        setState(() {
          variables[name] = '';
          variableControllers[name] = TextEditingController();
        });
        newVariableController.clear();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('变量名格式不正确')),
      );
    }
  }

  Future<void> _deleteVariable(String name) async {
    if (workspacePath != null && currentPromptName != null) {
      final promptDir = Directory('$workspacePath/prompt/$currentPromptName');
      final file = File('${promptDir.path}/$name.md');
      if (await file.exists()) {
        await file.delete();
      }
      setState(() {
        variables.remove(name);
        variableControllers[name]?.dispose();
        variableControllers.remove(name);
      });
    }
  }

  Future<void> _updateVariable(String name, String value) async {
    if (workspacePath != null && currentPromptName != null) {
      final promptDir = Directory('$workspacePath/prompt/$currentPromptName');
      final file = File('${promptDir.path}/$name.md');
      await file.writeAsString(value);
      setState(() {
        variables[name] = value;
      });
    }
  }

  Future<void> _updateTemplate(String value) async {
    if (workspacePath != null && currentPromptName != null) {
      final promptDir = Directory('$workspacePath/prompt/$currentPromptName');
      final file = File('${promptDir.path}/template.md');
      await file.writeAsString(value);
      setState(() {
        template = value;
      });
    }
  }

  String _renderResult() {
    var result = templateController.text;
    for (final entry in variableControllers.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value.text);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompt 编辑器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: _selectWorkspace,
            tooltip: '选择工作目录',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createPrompt,
            tooltip: '新建 Prompt',
          ),
        ],
      ),
      body: Row(
        children: [
          // 左侧 Prompt 列表
          SizedBox(
            width: 200,
            child: Card(
              margin: const EdgeInsets.all(8),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Prompt 列表',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: FutureBuilder<List<FileSystemEntity>>(
                      future: workspacePath != null
                          ? Directory('$workspacePath/prompt').list().toList()
                          : Future.value([]),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final prompts = snapshot.data!
                            .where((entity) => entity is Directory)
                            .map((entity) => entity.path.split('/').last)
                            .toList();
                        return ListView.builder(
                          itemCount: prompts.length,
                          itemBuilder: (context, index) {
                            final promptName = prompts[index];
                            return ListTile(
                              title: Text(promptName),
                              selected: promptName == currentPromptName,
                              onTap: () => _loadPrompt(promptName),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 右侧编辑区域
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentPromptName != null) ...[
                    Text('当前 Prompt: $currentPromptName',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('Prompt Template:'),
                    Container(
                      height: 150, // 固定高度，大约5行
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: TextField(
                          controller: templateController,
                          maxLines: null,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(8),
                            hintText: '输入模板，使用 {变量名} 作为占位符',
                          ),
                          onChanged: _updateTemplate,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('变量输入:', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: newVariableController,
                            decoration: const InputDecoration(
                              hintText: '输入新变量名',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addVariable,
                          child: const Text('添加变量'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          ...variableControllers.entries.map((entry) => Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: entry.value,
                                              decoration: InputDecoration(
                                                labelText: entry.key,
                                                border:
                                                    const OutlineInputBorder(),
                                              ),
                                              onChanged: (value) =>
                                                  _updateVariable(
                                                      entry.key, value),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () =>
                                                _deleteVariable(entry.key),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('生成结果:', style: TextStyle(fontSize: 16)),
                    Container(
                      width: double.infinity,
                      height: 150, // 固定高度，与模板输入区域一致
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(_renderResult()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _renderResult()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制到剪贴板')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('复制结果'),
                    ),
                  ] else
                    const Center(
                      child: Text('请选择或创建一个 Prompt',
                          style: TextStyle(fontSize: 18)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
