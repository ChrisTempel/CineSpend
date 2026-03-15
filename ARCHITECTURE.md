# CineSpend Architecture

This document provides an overview of CineSpend's code structure and design decisions.

## Project Structure

```
CineSpend/
├── CineSpendApp.swift          # App entry point, menus, appearance settings
├── ContentView.swift            # Main split view layout
├── TopSheetView.swift           # Budget overview (left pane)
├── CategoryDetailView.swift    # Category details & unit calculator (right pane)
├── Models.swift                 # Data models (Project, Category, LineItem, UnitBreakdown)
├── ProjectManager.swift         # File I/O, PDF generation
├── CineSpend.entitlements      # App Sandbox permissions
└── Info.plist                   # App metadata

```

## Architecture Overview

### MVVM Pattern

CineSpend follows the Model-View-ViewModel (MVVM) pattern:

- **Models** (`Models.swift`): Data structures for Project, BudgetCategory, LineItem, UnitBreakdown
- **Views** (`*View.swift`): SwiftUI views for UI presentation
- **ViewModel** (`ProjectManager`): Manages project state, file operations, PDF generation

### Data Flow

```
User Input → SwiftUI Binding → Model Update → Automatic UI Refresh
                                    ↓
                           ProjectManager (if save/export)
```

SwiftUI's `@Binding` and `@Published` properties handle most state management automatically.

## Key Components

### Models.swift

**Project**
- Top-level container for an entire budget
- Contains array of `BudgetCategory`
- Stores metadata: name, preparedBy, contingencyPercentage, dates

**BudgetCategory**
- Represents one budget category (1000-19000)
- Contains array of `LineItem`
- Computed properties for totals

**LineItem**
- Individual budget line (e.g., "Director", "Camera Rental")
- Contains array of `UnitBreakdown` for detailed calculations
- Has estimated, actual, and notes fields

**UnitBreakdown**
- Detailed cost calculation: amount × units × rate
- Separate rates for estimated vs. actual

### ProjectManager.swift

**Responsibilities:**
- Create/save/load projects (`.cinespend` JSON files)
- Export PDFs using Core Graphics
- Manages `currentProject` state with `@Published`

**PDF Generation:**
- Uses `CGContext` for drawing
- Generates multi-page PDFs (top sheet + detail pages)
- Custom text rendering with proper layout

### Views

**ContentView**
- Root view with `HSplitView` for left/right panes
- Manages selected category state
- Provides custom binding to ProjectManager

**TopSheetView**
- Displays all categories with totals
- Shows subtotal, contingency (editable %), and grand total
- Handles automatic contingency calculation via `onChange`

**CategoryDetailView**
- Shows line items for selected category
- Calculator sheets for estimated/actual values
- Unit breakdown table with real-time calculations

## State Management

### Bindings

SwiftUI `@Binding` creates two-way data flow:

```swift
@Binding var project: Project  // TopSheetView receives this
                                // Changes propagate automatically

project.contingencyPercentage = 15  // UI updates instantly
```

### Automatic Updates

Contingency calculation uses `onChange` modifiers:

```swift
.onChange(of: project.contingencyPercentage) { _ in
    autoUpdateContingency()  // Recalculate when % changes
}
.onChange(of: subtotalEstimated) { _ in
    autoUpdateContingency()  // Recalculate when subtotal changes
}
```

### Refresh Trigger

For complex updates (e.g., calculator closing), uses a UUID trigger:

```swift
@State private var refreshTrigger = UUID()

// When calculator updates values:
refreshTrigger = UUID()  // Forces TopSheetView to recalculate
```

## Design Decisions

### Why Three-Level Hierarchy?

Matches industry-standard budgeting software (Movie Magic):
1. **Top Sheet**: High-level overview for investors
2. **Category Detail**: Department-level planning
3. **Unit Breakdown**: Granular calculations (crew × days × rate)

### Why Calculator Popups?

Alternative approaches considered:
- ❌ Inline expandable rows - cluttered UI, update issues
- ❌ Separate detail window - lost context
- ✅ Modal calculator sheets - clean, focused, proper state management

### Why JSON Files?

- Human-readable for debugging
- Easy to version control
- Future-proof (easy to migrate)
- Cross-platform compatible

### Why Automatic Contingency?

Industry standard is 10%, but varies by production:
- Documentary: 5-10%
- Narrative: 10-15%
- International shoots: 15-20%

Making it automatic (but editable) reduces errors while maintaining flexibility.

## Performance Considerations

### Lazy Loading

Category list uses `LazyVStack` to only render visible items:

```swift
ScrollView {
    LazyVStack {  // Only creates views as needed
        ForEach(categories) { ... }
    }
}
```

### Computed Properties

Totals are computed properties, not stored values:

```swift
var totalEstimated: Double {
    categories.reduce(0) { $0 + $1.totalEstimated }
}
```

This ensures totals are always accurate without manual updating.

## Extension Points

### Adding New Features

**New Budget Category:**
1. Add to `BudgetCategory.defaultCategories()` in Models.swift
2. No other changes needed - UI adapts automatically

**New Export Format:**
1. Add method to ProjectManager
2. Add menu item in CineSpendApp
3. Implement export logic

**New Calculator Field:**
1. Add property to `UnitBreakdown` in Models.swift
2. Add column to `UnitRow` in CategoryDetailView
3. Update calculation logic

## Testing Strategy

Currently manual testing. Future additions could include:

- Unit tests for calculation logic
- UI tests for critical workflows
- Snapshot tests for PDF output
- Performance tests for large budgets

## Dependencies

**Zero external dependencies** - uses only Apple frameworks:
- SwiftUI (UI)
- AppKit (PDF generation, file dialogs)
- Foundation (data structures, JSON)
- Combine (reactive state management)

This keeps the app lightweight and reduces maintenance burden.

## Future Architecture Considerations

If scaling CineSpend:

- **Document-based app**: Use `NSDocument` for better macOS integration
- **Core Data**: For complex queries and relationships
- **CloudKit**: For sync across devices
- **Widgets**: Dashboard view of current budget
- **Scriptability**: AppleScript support for automation

---

**Design Philosophy**: Simple, clean, and focused on the filmmaker's workflow.
