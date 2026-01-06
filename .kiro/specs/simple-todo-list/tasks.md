# Implementation Plan: Simple Todo List

## Overview

This plan implements a simple todo list feature with a floating action button on the dashboard and a dedicated todo page with local persistence.

## Tasks

- [x] 1. Create TodoItem entity and JSON serialization
  - Create `lib/domain/entities/todo_item.dart`
  - Implement TodoItem class with id, description, isCompleted, createdAt
  - Implement toJson() and fromJson() methods
  - Implement copyWith() method
  - _Requirements: 6.1_

- [ ]* 1.1 Write property test for TodoItem JSON round-trip
  - **Property 6: TodoItem JSON serialization round-trip**
  - **Validates: Requirements 6.1**

- [x] 2. Create Todo storage service
  - Create `lib/data/datasources/todo_storage_service.dart`
  - Implement loadTodos() to read from SharedPreferences
  - Implement saveTodos() to write to SharedPreferences
  - Handle storage errors gracefully
  - _Requirements: 6.1, 6.2_

- [ ]* 2.1 Write property test for persistence round-trip
  - **Property 5: Persistence round-trip**
  - **Validates: Requirements 6.1, 6.2**

- [x] 3. Create Todo page UI
  - Create `lib/presentation/pages/todo_page.dart`
  - Implement scrollable list of todo items
  - Implement empty state when no items exist
  - Display each item with checkbox and description
  - Show strikethrough for completed items
  - _Requirements: 2.1, 2.2, 2.3, 4.2_

- [x] 4. Implement add todo functionality
  - Add text input field with submit button
  - Validate input (reject empty/whitespace)
  - Create new TodoItem and add to list
  - Clear input field after successful add
  - Persist changes to storage
  - _Requirements: 3.1, 3.2, 3.3_

- [ ]* 4.1 Write property test for adding valid tasks
  - **Property 1: Adding valid task increases list size**
  - **Validates: Requirements 3.1**

- [ ]* 4.2 Write property test for whitespace rejection
  - **Property 2: Whitespace-only tasks are rejected**
  - **Validates: Requirements 3.2**

- [x] 5. Implement toggle completion functionality
  - Handle checkbox tap to toggle isCompleted
  - Update visual styling (strikethrough)
  - Persist changes to storage
  - _Requirements: 4.1, 4.2_

- [ ]* 5.1 Write property test for toggle completion
  - **Property 3: Toggle flips completion status**
  - **Validates: Requirements 4.1**

- [x] 6. Implement delete todo functionality
  - Add swipe-to-delete with Dismissible widget
  - Remove item from list on delete
  - Persist changes to storage
  - _Requirements: 5.1, 5.2_

- [ ]* 6.1 Write property test for delete functionality
  - **Property 4: Delete removes item from list**
  - **Validates: Requirements 5.1**

- [x] 7. Update Dashboard with FAB stack
  - Modify `lib/presentation/pages/dashboard_page.dart`
  - Replace single FAB with Column containing two FABs
  - Add todo FAB with checklist icon above manual entry FAB
  - Implement navigation to Todo page
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 8. Add route for Todo page
  - Update `lib/core/routes/app_routes.dart` with todo route
  - Add navigation helper method
  - _Requirements: 1.2_

- [x] 9. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ]* 10. Write widget tests for UI components
  - Test FAB stack layout on dashboard
  - Test navigation to todo page
  - Test empty state display
  - Test todo item rendering
  - _Requirements: 1.1, 1.2, 2.2, 2.3_

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties
- The feature uses SharedPreferences for simple local persistence
