import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/todo_item.dart';

/// Storage service for todo items using SharedPreferences
/// 
/// Provides local persistence for todo items with graceful error handling.
/// Requirements: 6.1, 6.2
class TodoStorageService {
  static const String _storageKey = 'todo_items';
  
  SharedPreferences? _prefs;
  
  /// Initialize the storage service
  /// 
  /// Must be called before any other operations.
  /// Can optionally accept a SharedPreferences instance for testing.
  Future<void> initialize([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
  }
  
  /// Load all todo items from local storage
  /// 
  /// Returns an empty list if no items exist or if there's a storage error.
  /// Requirements: 6.2
  Future<List<TodoItem>> loadTodos() async {
    _ensureInitialized();
    
    try {
      final jsonString = _prefs!.getString(_storageKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = json.decode(jsonString);
      
      return jsonList
          .map((item) => TodoItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      // Log error and return empty list on failure
      print('Error loading todos from storage: $e');
      return [];
    }
  }
  
  /// Save all todo items to local storage
  /// 
  /// Persists the entire list, replacing any existing data.
  /// Requirements: 6.1
  Future<bool> saveTodos(List<TodoItem> todos) async {
    _ensureInitialized();
    
    try {
      final jsonList = todos.map((item) => item.toJson()).toList();
      final jsonString = json.encode(jsonList);
      
      return await _prefs!.setString(_storageKey, jsonString);
    } catch (e) {
      // Log error and return false on failure
      print('Error saving todos to storage: $e');
      return false;
    }
  }
  
  /// Add a single todo item to storage
  /// 
  /// Loads existing items, adds the new one, and saves back.
  /// Requirements: 6.1
  Future<bool> addTodo(TodoItem todo) async {
    try {
      final todos = await loadTodos();
      todos.add(todo);
      return await saveTodos(todos);
    } catch (e) {
      print('Error adding todo to storage: $e');
      return false;
    }
  }
  
  /// Update an existing todo item in storage
  /// 
  /// Finds the item by ID and replaces it with the updated version.
  /// Requirements: 6.1
  Future<bool> updateTodo(TodoItem todo) async {
    try {
      final todos = await loadTodos();
      final index = todos.indexWhere((item) => item.id == todo.id);
      
      if (index == -1) {
        return false;
      }
      
      todos[index] = todo;
      return await saveTodos(todos);
    } catch (e) {
      print('Error updating todo in storage: $e');
      return false;
    }
  }
  
  /// Delete a todo item from storage by ID
  /// 
  /// Requirements: 6.1
  Future<bool> deleteTodo(String id) async {
    try {
      final todos = await loadTodos();
      final initialLength = todos.length;
      todos.removeWhere((item) => item.id == id);
      
      if (todos.length == initialLength) {
        // Item not found
        return false;
      }
      
      return await saveTodos(todos);
    } catch (e) {
      print('Error deleting todo from storage: $e');
      return false;
    }
  }
  
  /// Clear all todo items from storage
  Future<bool> clearTodos() async {
    _ensureInitialized();
    
    try {
      return await _prefs!.remove(_storageKey);
    } catch (e) {
      print('Error clearing todos from storage: $e');
      return false;
    }
  }
  
  /// Ensure the service is initialized before operations
  void _ensureInitialized() {
    if (_prefs == null) {
      throw StateError(
        'TodoStorageService not initialized. Call initialize() first.',
      );
    }
  }
}
