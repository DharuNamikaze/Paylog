import 'package:flutter/material.dart';
import '../../domain/entities/todo_item.dart';
import '../../data/datasources/todo_storage_service.dart';
import '../../core/theme/app_theme.dart';

/// Todo list page for managing personal tasks
/// 
/// Requirements: 2.1, 2.2, 2.3, 4.2
class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final TodoStorageService _storageService = TodoStorageService();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  List<TodoItem> _todos = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  /// Initialize storage service and load todos
  Future<void> _initializeAndLoad() async {
    try {
      await _storageService.initialize();
      await _loadTodos();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize storage: $e';
      });
    }
  }

  /// Load todos from storage
  /// Requirements: 2.1
  Future<void> _loadTodos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final todos = await _storageService.loadTodos();
      setState(() {
        _todos = todos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load todos: $e';
      });
    }
  }

  /// Toggle completion status of a todo item
  /// Requirements: 4.1, 4.2
  Future<void> _toggleTodo(TodoItem todo) async {
    final updatedTodo = todo.copyWith(isCompleted: !todo.isCompleted);
    
    // Optimistic update
    setState(() {
      final index = _todos.indexWhere((t) => t.id == todo.id);
      if (index != -1) {
        _todos[index] = updatedTodo;
      }
    });

    // Persist change
    final success = await _storageService.updateTodo(updatedTodo);
    if (!success && mounted) {
      // Revert on failure
      setState(() {
        final index = _todos.indexWhere((t) => t.id == todo.id);
        if (index != -1) {
          _todos[index] = todo;
        }
      });
      _showErrorSnackbar('Failed to update todo');
    }
  }

  /// Validate task description input
  /// Returns null if valid, error message if invalid
  /// Requirements: 3.2
  String? _validateInput(String input) {
    if (input.trim().isEmpty) {
      return 'Task description cannot be empty';
    }
    return null;
  }

  /// Add a new todo item
  /// Requirements: 3.1, 3.2, 3.3
  Future<void> _addTodo() async {
    final description = _inputController.text;
    
    // Validate input
    final validationError = _validateInput(description);
    if (validationError != null) {
      setState(() {
        _inputError = validationError;
      });
      return;
    }

    // Clear any previous validation error
    setState(() {
      _inputError = null;
    });

    // Create new todo item
    final newTodo = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      description: description.trim(),
      isCompleted: false,
      createdAt: DateTime.now(),
    );

    // Optimistic update - add to list
    setState(() {
      _todos.insert(0, newTodo);
      _inputController.clear();
    });

    // Persist to storage
    final success = await _storageService.addTodo(newTodo);
    if (!success && mounted) {
      // Revert on failure
      setState(() {
        _todos.removeWhere((t) => t.id == newTodo.id);
      });
      _showErrorSnackbar('Failed to add todo');
    }
  }

  /// Show error snackbar
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildInputField(),
        ],
      ),
    );
  }

  /// Build the input field for adding new todos
  /// Requirements: 3.1, 3.2, 3.3
  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Add a new task...',
                      errorText: _inputError,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addTodo(),
                    onChanged: (_) {
                      // Clear error when user starts typing
                      if (_inputError != null) {
                        setState(() {
                          _inputError = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _addTodo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build the main body content
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_todos.isEmpty) {
      return _buildEmptyState();
    }

    return _buildTodoList();
  }

  /// Build error state widget
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTodos,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state widget
  /// Requirements: 2.2
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.checklist_outlined,
              size: 80,
              color: AppTheme.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No tasks yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first task to get started!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build scrollable todo list
  /// Requirements: 2.1, 2.3
  Widget _buildTodoList() {
    return RefreshIndicator(
      onRefresh: _loadTodos,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: _todos.length,
        itemBuilder: (context, index) {
          final todo = _todos[index];
          return _buildTodoItem(todo);
        },
      ),
    );
  }

  /// Delete a todo item
  /// Requirements: 5.1, 5.2
  Future<void> _deleteTodo(TodoItem todo) async {
    // Optimistic update - remove from list
    final index = _todos.indexWhere((t) => t.id == todo.id);
    setState(() {
      _todos.removeWhere((t) => t.id == todo.id);
    });

    // Persist change
    final success = await _storageService.deleteTodo(todo.id);
    if (!success && mounted) {
      // Revert on failure - insert back at original position
      setState(() {
        if (index >= 0 && index <= _todos.length) {
          _todos.insert(index, todo);
        } else {
          _todos.add(todo);
        }
      });
      _showErrorSnackbar('Failed to delete todo');
    }
  }

  /// Build individual todo item with swipe-to-delete
  /// Requirements: 2.3, 4.2, 5.1, 5.2
  Widget _buildTodoItem(TodoItem todo) {
    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: AppTheme.errorRed,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) => _deleteTodo(todo),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: ListTile(
          leading: Checkbox(
            value: todo.isCompleted,
            onChanged: (_) => _toggleTodo(todo),
            activeColor: AppTheme.successGreen,
          ),
          title: Text(
            todo.description,
            style: TextStyle(
              decoration: todo.isCompleted 
                  ? TextDecoration.lineThrough 
                  : TextDecoration.none,
              color: todo.isCompleted 
                  ? AppTheme.textMuted 
                  : null,
            ),
          ),
          onTap: () => _toggleTodo(todo),
        ),
      ),
    );
  }
}
