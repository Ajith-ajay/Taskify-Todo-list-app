import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  final appDocumentDirectory =
      await path_provider.getApplicationDocumentsDirectory();
  Hive.init(appDocumentDirectory.path);
  Hive.registerAdapter(TodoAdapter());
  await Hive.openBox<Todo>('todos');

  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Todo Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TodoList(title: 'Todo Manager'),
    );
  }
}

class TodoList extends StatefulWidget {
  const TodoList({super.key, required this.title});

  final String title;

  @override
  State<TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  final TextEditingController _textFieldController = TextEditingController();
  late Box<Todo> todosBox;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    todosBox = Hive.box<Todo>('todos');
  }

  List<Todo> get _todos => todosBox.values.toList();

  void _loadTodos() {
    setState(() {});
  }

  void _addTodoItem(String name, DateTime? createdTime) async {
    if (name.trim().isEmpty) {
      _showErrorMessage('Please enter a todo item');
      return;
    }

    final newTodo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      completed: false,
      createdTime: createdTime ?? DateTime.now(),
    );

    try {
      await todosBox.add(newTodo);
      _textFieldController.clear();
      _showSuccessMessage('Todo added successfully!');
      _loadTodos();
    } catch (e) {
      debugPrint('Error adding todo: $e');
      _showErrorMessage('Failed to add todo. Please try again.');
    }
  }

  void _handleTodoChange(Todo todo) async {
    setState(() {
      todo.completed = !todo.completed;
    });

    // Update in Hive
    final index = _todos.indexWhere((t) => t.id == todo.id);
    if (index != -1) {
      await todosBox.putAt(index, todo);
    }
  }

  void _deleteTodo(Todo todo) async {
    bool? shouldDelete = await _showDeleteConfirmation(todo.name);
    if (shouldDelete != true) return;

    final index = _todos.indexWhere((t) => t.id == todo.id);
    if (index != -1) {
      await todosBox.deleteAt(index);
      _loadTodos();
    }

    _showSuccessMessage('Todo deleted successfully');
  }

  Future<bool?> _showDeleteConfirmation(String todoName) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Todo'),
          content: Text('Are you sure you want to delete "$todoName"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<Todo> get _filteredTodos {
    final now = DateTime.now();
    switch (_selectedTab) {
      case 1: // Today
        return _todos.where((todo) {
          return todo.createdTime != null &&
              todo.createdTime!.year == now.year &&
              todo.createdTime!.month == now.month &&
              todo.createdTime!.day == now.day;
        }).toList();
      default: // All
        return _todos;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _displayDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          SizedBox(
            height: 50,
            child: Row(
              children: [
                _buildTabButton('All (${_todos.length})', 0),
                _buildTabButton(
                  'Today (${_todos.where((todo) {
                    final now = DateTime.now();
                    return todo.createdTime != null &&
                        todo.createdTime!.year == now.year &&
                        todo.createdTime!.month == now.month &&
                        todo.createdTime!.day == now.day;
                  }).length})',
                  1,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Todo List
          Expanded(
            child: _filteredTodos.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.checklist, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No todos yet!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ListView.builder(
                      itemCount: _filteredTodos.length,
                      itemBuilder: (context, index) {
                        final todo = _filteredTodos[index];
                        return _buildNotebookTodoItem(todo);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _selectedTab == index ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight:
                  _selectedTab == index ? FontWeight.bold : FontWeight.normal,
              color: _selectedTab == index ? Colors.blue : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotebookTodoItem(Todo todo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: todo.completed,
                onChanged: (value) => _handleTodoChange(todo),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              todo.name,
              style: TextStyle(
                fontSize: 16,
                decoration: todo.completed ? TextDecoration.lineThrough : null,
                color: todo.completed ? Colors.grey : Colors.black,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: () => _showTodoOptions(todo),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showTodoOptions(Todo todo) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteTodo(todo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editTodo(todo);
              },
            ),
          ],
        );
      },
    );
  }

  void _editTodo(Todo todo) {
    _textFieldController.text = todo.name;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Todo'),
          content: TextField(
            controller: _textFieldController,
            decoration: const InputDecoration(
              hintText: 'Edit your todo',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedTodo = Todo(
                  id: todo.id,
                  name: _textFieldController.text,
                  completed: todo.completed,
                  createdTime: todo.createdTime,
                );
                _updateTodo(updatedTodo);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _updateTodo(Todo updatedTodo) async {
    final index = _todos.indexWhere((t) => t.id == updatedTodo.id);
    if (index != -1) {
      await todosBox.putAt(index, updatedTodo);
      setState(() {});
      _showSuccessMessage('Todo updated successfully!');
    }
  }

  Future<void> _displayDialog() async {
    if (!context.mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add a todo'),
          content: TextField(
            controller: _textFieldController,
            decoration: const InputDecoration(
              hintText: 'Type your todo',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            maxLength: 100,
          ),
          actions: <Widget>[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _addTodoItem(_textFieldController.text, DateTime.now());
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

@HiveType(typeId: 0)
class Todo extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String name;

  @HiveField(2)
  bool completed;

  @HiveField(3)
  DateTime? createdTime;

  Todo({
    this.id,
    required this.name,
    required this.completed,
    required this.createdTime,
  });
}

class TodoAdapter extends TypeAdapter<Todo> {
  @override
  final int typeId = 0;

  @override
  Todo read(BinaryReader reader) {
    return Todo(
      id: reader.read(),
      name: reader.read(),
      completed: reader.read(),
      createdTime: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, Todo obj) {
    writer.write(obj.id);
    writer.write(obj.name);
    writer.write(obj.completed);
    writer.write(obj.createdTime);
  }
}
