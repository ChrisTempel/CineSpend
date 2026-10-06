//
//  TopSheetView.swift
//  CineSpend
//
//  Top sheet showing all budget categories with totals
//

import SwiftUI

// MARK: - Numeric Field
//
// TextField(value:format: .number) reformats through its format style live, on every
// keystroke - for multi-digit numbers this can visibly mangle or revert what you just
// typed mid-entry (SwiftUI/macOS: the field is fighting its own formatter for the
// selection/cursor state). This edits a plain String instead and only converts to/from
// Double at the boundary, so nothing reformats out from under an in-progress edit.
// Used everywhere a Double is typed directly: unit rows, project/category contingency %.
struct NumericField: View {
    @Binding var value: Double
    @State private var text: String

    init(value: Binding<Double>) {
        self._value = value
        self._text = State(initialValue: Self.format(value.wrappedValue))
    }

    var body: some View {
        TextField("", text: $text)
            .onChange(of: text) { _, newText in
                if let parsed = Double(newText) {
                    value = parsed
                }
            }
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(value)
    }
}

// MARK: - Inline Editable Text
//
// Shows plain Text until double-clicked, then swaps to a focused TextField - so a row
// that also does something on single click (e.g. selecting an account and opening its
// detail view) doesn't have that click swallowed by the text field starting an edit
// instead. onActivate fires on every confirmed single click (and again just before an
// edit starts on double-click, since a double-click implies the row was clicked too);
// pass nil where there's nothing to activate, e.g. a field that's already the sole
// subject of its own view. Used by CategoryRow's account/name cells and by
// CategoryDetailView's header.
struct InlineEditableText: View {
    @Binding var text: String
    let placeholder: String
    var onActivate: (() -> Void)? = nil
    // Set true when this field's row already has the accentColor selection wash
    // (CategoryRow's isSelected) - the system's default text-selection blue nearly
    // disappears against that, so a darker tint is used instead.
    var isRowSelected: Bool = false

    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    private static let selectedRowTint = Color(red: 0.04, green: 0.22, blue: 0.52)

    var body: some View {
        Group {
            if isEditing {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .tint(isRowSelected ? Self.selectedRowTint : .accentColor)
                    .focused($isFocused)
                    .onSubmit { isEditing = false }
            } else {
                Text(text)
                    .contentShape(Rectangle())
                    .gesture(
                        TapGesture(count: 2)
                            .onEnded {
                                onActivate?()
                                isEditing = true
                                isFocused = true
                            }
                            .exclusively(before: TapGesture(count: 1).onEnded {
                                onActivate?()
                            })
                    )
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { isEditing = false }
        }
    }
}

// MARK: - Sort Support
//
// Shared by TopSheetView and CategoryDetailView: clicking a header sorts the list once
// (toggling direction on repeat clicks of the same header), it's not a persistent sort
// mode - rows stay freely drag-reorderable afterward.
struct ColumnSort<Column: Equatable> {
    var column: Column
    var ascending: Bool

    static func next(after current: ColumnSort<Column>?, tapped column: Column) -> ColumnSort<Column> {
        if let current, current.column == column {
            return ColumnSort(column: column, ascending: !current.ascending)
        }
        return ColumnSort(column: column, ascending: true)
    }
}

struct TopSheetView: View {
    @Binding var project: Project
    @Binding var selectedCategoryID: UUID?
    let updateTrigger: UUID
    @EnvironmentObject var projectManager: ProjectManager
    @Environment(\.undoManager) private var undoManager
    @State private var editingProjectName = false
    @State private var draggingCategoryID: UUID?
    @State private var sort: ColumnSort<CategoryColumn>?
    @State private var selectedCategoryIDs: Set<UUID> = []
    @State private var selectionAnchorID: UUID?

    enum CategoryColumn {
        case account, name, estimated, percentage, actual, remaining
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 10) {
                if editingProjectName {
                    TextField("Project Name", text: $project.name, onCommit: {
                        editingProjectName = false
                    })
                    .textFieldStyle(.roundedBorder)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                } else {
                    Text(project.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .onTapGesture {
                            editingProjectName = true
                        }
                }
                
                HStack {
                    Text("BUDGET TOP SHEET")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: addCategory) {
                        Label("Add Account", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack {
                    Text("Modified: \(formattedDate(project.dateModified))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Prepared by:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Your Name", text: $project.preparedBy)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Column Headers
            HStack {
                Text("").frame(width: 30) // aligns with the drag handle column below

                sortHeader("ACCT", column: .account, width: 60, alignment: .leading)
                sortHeader("CATEGORY", column: .name, alignment: .leading)
                sortHeader("ESTIMATED", column: .estimated, width: 100, alignment: .trailing)
                sortHeader("%", column: .percentage, width: 50, alignment: .trailing)
                sortHeader("ACTUAL", column: .actual, width: 100, alignment: .trailing)
                sortHeader("REMAINING", column: .remaining, width: 100, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Category List (excluding Contingency)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(nonContingencyCategories) { $category in
                        CategoryRow(
                            category: $category,
                            currency: project.currency,
                            totalBudget: subtotalEstimated,
                            selectedIDs: selectedCategoryIDs,
                            onSelect: { handleSelection(of: category.id) },
                            onDelete: { deleteCategories(ids: $0) },
                            onDuplicate: { duplicateCategories(ids: $0) },
                            draggingID: $draggingCategoryID
                        )
                        .onDrop(of: [.text], delegate: CategoryDropDelegate(
                            item: category,
                            categories: nonContingencyCategories,
                            draggingID: $draggingCategoryID
                        ))
                        Divider()
                    }
                }
            }

            Divider()
            
            // Subtotal (excluding contingency)
            HStack {
                Text("SUBTOTAL")
                    .frame(width: 60, alignment: .leading)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(formatCurrency(subtotalEstimated))
                    .frame(width: 100, alignment: .trailing)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(formatCurrency(subtotalActual))
                    .frame(width: 100, alignment: .trailing)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(formatCurrency(subtotalRemaining))
                    .frame(width: 100, alignment: .trailing)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(subtotalRemaining >= 0 ? .green : .red)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            // Contingency Row - accountNumber/name are ordinary editable fields, same as
            // any other category; isProjectContingency (not the account number) is what
            // actually identifies this row to the app.
            if let contingencyIndex = project.categories.firstIndex(where: { $0.isProjectContingency }) {
                HStack {
                    InlineEditableText(text: $project.categories[contingencyIndex].accountNumber, placeholder: "Acct")
                        .frame(width: 60, alignment: .leading)
                        .font(.system(.body, design: .monospaced))

                    HStack(spacing: 4) {
                        InlineEditableText(text: $project.categories[contingencyIndex].name, placeholder: "Name")
                            .frame(alignment: .leading)

                        NumericField(value: $project.contingencyPercentage)
                            .textFieldStyle(.plain)
                            .frame(width: 35)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.blue)

                        Text("%")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(formatCurrency(project.categories[contingencyIndex].totalEstimated))
                        .frame(width: 100, alignment: .trailing)
                        .font(.system(.body, design: .monospaced))

                    Text("")
                        .frame(width: 50, alignment: .trailing)

                    Text(formatCurrency(project.categories[contingencyIndex].totalActual))
                        .frame(width: 100, alignment: .trailing)
                        .font(.system(.body, design: .monospaced))

                    Text(formatCurrency(project.categories[contingencyIndex].totalRemaining))
                        .frame(width: 100, alignment: .trailing)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(project.categories[contingencyIndex].totalRemaining >= 0 ? .green : .red)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.clear)
            }
            
            Divider()
            
            // Grand Total
            HStack {
                Text("TOTAL")
                    .frame(width: 60, alignment: .leading)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(formatCurrency(project.totalEstimated))
                    .frame(width: 100, alignment: .trailing)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(formatCurrency(project.totalActual))
                    .frame(width: 100, alignment: .trailing)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(formatCurrency(project.totalRemaining))
                    .frame(width: 100, alignment: .trailing)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(project.totalRemaining >= 0 ? .green : .red)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onChange(of: project.contingencyPercentage) {
            autoUpdateContingency()
        }
        .onChange(of: updateTrigger) {
            autoUpdateContingency()
        }
        .onChange(of: subtotalEstimated) {
            autoUpdateContingency()
        }
        .onAppear {
            autoUpdateContingency()
        }
    }
    
    // Subtotal = everything EXCEPT the project contingency
    private var subtotalEstimated: Double {
        project.categories
            .filter { !$0.isProjectContingency }
            .reduce(0) { $0 + $1.totalEstimated }
    }

    private var subtotalActual: Double {
        project.categories
            .filter { !$0.isProjectContingency }
            .reduce(0) { $0 + $1.totalActual }
    }

    private var subtotalRemaining: Double {
        subtotalEstimated - subtotalActual
    }

    // Excludes the project contingency, which is rendered separately below and is
    // never draggable/deletable/sortable alongside the regular accounts.
    private var nonContingencyCategories: Binding<[BudgetCategory]> {
        Binding(
            get: { project.categories.filter { !$0.isProjectContingency } },
            set: { newValue in
                let contingency = project.categories.filter { $0.isProjectContingency }
                project.categories = newValue + contingency
            }
        )
    }

    @ViewBuilder
    private func sortHeader(_ title: String, column: CategoryColumn, width: CGFloat? = nil, alignment: Alignment) -> some View {
        let label = HStack(spacing: 2) {
            Text(title)
            if sort?.column == column {
                Image(systemName: sort!.ascending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .font(.caption)
        .fontWeight(.bold)
        .contentShape(Rectangle())
        .onTapGesture { applySort(column) }

        if let width {
            label.frame(width: width, alignment: alignment)
        } else {
            label.frame(maxWidth: .infinity, alignment: alignment)
        }
    }

    private func applySort(_ column: CategoryColumn) {
        let newSort = ColumnSort.next(after: sort, tapped: column)
        sort = newSort

        var reordered = nonContingencyCategories.wrappedValue
        let ascending = newSort.ascending
        switch column {
        case .account:
            reordered.sort { ascending ? $0.accountNumber < $1.accountNumber : $0.accountNumber > $1.accountNumber }
        case .name:
            reordered.sort {
                let order = $0.name.localizedStandardCompare($1.name)
                return ascending ? order == .orderedAscending : order == .orderedDescending
            }
        case .estimated, .percentage:
            reordered.sort { ascending ? $0.totalEstimated < $1.totalEstimated : $0.totalEstimated > $1.totalEstimated }
        case .actual:
            reordered.sort { ascending ? $0.totalActual < $1.totalActual : $0.totalActual > $1.totalActual }
        case .remaining:
            reordered.sort { ascending ? $0.totalRemaining < $1.totalRemaining : $0.totalRemaining > $1.totalRemaining }
        }
        nonContingencyCategories.wrappedValue = reordered
    }

    private func addCategory() {
        let newCategory = BudgetCategory(accountNumber: "", name: "New Account", lineItems: [])
        if let contingencyIndex = project.categories.firstIndex(where: { $0.isProjectContingency }) {
            project.categories.insert(newCategory, at: contingencyIndex)
        } else {
            project.categories.append(newCategory)
        }
        selectedCategoryID = newCategory.id
        selectedCategoryIDs = [newCategory.id]
        selectionAnchorID = newCategory.id
    }

    // MARK: - Selection
    //
    // Finder-style: a plain click replaces the selection and resets the shift-click
    // anchor; Cmd-click toggles one row in/out of the selection and moves the anchor
    // there; Shift-click selects the contiguous range between the anchor and the
    // clicked row, leaving the anchor where it was so repeated shift-clicks keep
    // extending/contracting from the same point. selectedCategoryID (the single
    // account shown on the right) always follows the row that was just clicked.
    private func handleSelection(of id: UUID) {
        let modifiers = NSEvent.modifierFlags
        let orderedIDs = nonContingencyCategories.wrappedValue.map { $0.id }

        if modifiers.contains(.shift), let anchor = selectionAnchorID,
           let anchorIndex = orderedIDs.firstIndex(of: anchor),
           let clickedIndex = orderedIDs.firstIndex(of: id) {
            let range = anchorIndex < clickedIndex ? anchorIndex...clickedIndex : clickedIndex...anchorIndex
            selectedCategoryIDs = Set(orderedIDs[range])
        } else if modifiers.contains(.command) {
            if selectedCategoryIDs.contains(id) {
                selectedCategoryIDs.remove(id)
            } else {
                selectedCategoryIDs.insert(id)
            }
            selectionAnchorID = id
        } else {
            selectedCategoryIDs = [id]
            selectionAnchorID = id
        }

        selectedCategoryID = selectedCategoryIDs.contains(id) ? id : selectedCategoryIDs.first
    }

    // MARK: - Delete with Undo

    private func deleteCategories(ids: Set<UUID>) {
        guard var current = projectManager.currentProject else { return }

        // Remove from the end so earlier indices stay valid, pushing undo in the same
        // order so a single Undo re-inserts every row at its original position.
        let indices = current.categories.indices.filter { ids.contains(current.categories[$0].id) }
        for index in indices.reversed() {
            let removed = current.categories[index]
            current.categories.remove(at: index)
            pushUndoInsert(removed, at: index)
        }
        projectManager.currentProject = current

        selectedCategoryIDs.subtract(ids)
        if let selectedCategoryID, ids.contains(selectedCategoryID) {
            self.selectedCategoryID = selectedCategoryIDs.first
        }
    }

    private func duplicateCategories(ids: Set<UUID>) {
        guard var current = projectManager.currentProject else { return }

        let indices = current.categories.indices.filter { ids.contains(current.categories[$0].id) }
        var newSelection: Set<UUID> = []
        for index in indices.reversed() {
            let original = current.categories[index]
            let duplicate = BudgetCategory(
                accountNumber: original.accountNumber,
                name: original.name + " (Copy)",
                lineItems: original.lineItems,
                contingencyPercentage: original.contingencyPercentage
            )
            current.categories.insert(duplicate, at: index + 1)
            newSelection.insert(duplicate.id)
        }
        projectManager.currentProject = current

        selectedCategoryIDs = newSelection
        selectionAnchorID = newSelection.first
        selectedCategoryID = newSelection.first
    }

    private func pushUndoInsert(_ category: BudgetCategory, at index: Int) {
        undoManager?.setActionName("Delete Account")
        undoManager?.registerUndo(withTarget: projectManager) { [self] target in
            guard var current = target.currentProject else { return }
            current.categories.insert(category, at: min(index, current.categories.count))
            target.currentProject = current
            pushUndoRemove(id: category.id)
        }
    }

    private func pushUndoRemove(id: UUID) {
        undoManager?.setActionName("Delete Account")
        undoManager?.registerUndo(withTarget: projectManager) { [self] target in
            guard var current = target.currentProject,
                  let index = current.categories.firstIndex(where: { $0.id == id }) else { return }
            let removed = current.categories[index]
            current.categories.remove(at: index)
            target.currentProject = current
            pushUndoInsert(removed, at: index)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func autoUpdateContingency() {
        guard let contingencyIndex = project.categories.firstIndex(where: { $0.isProjectContingency }),
              !project.categories[contingencyIndex].lineItems.isEmpty else {
            return
        }
        
        // Calculate contingency based on user-specified percentage
        let contingencyAmount = subtotalEstimated * (project.contingencyPercentage / 100.0)
        
        // Only update if value changed (avoid infinite loops)
        if abs(project.categories[contingencyIndex].lineItems[0].estimated - contingencyAmount) > 0.01 {
            var updatedProject = project
            updatedProject.categories[contingencyIndex].lineItems[0].estimated = contingencyAmount
            
            // Update description to show current percentage
            let percentText = project.contingencyPercentage == floor(project.contingencyPercentage) 
                ? String(format: "%.0f", project.contingencyPercentage)
                : String(format: "%.1f", project.contingencyPercentage)
            updatedProject.categories[contingencyIndex].lineItems[0].description = "Contingency (\(percentText)%)"
            
            project = updatedProject
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = project.currency.code
        formatter.currencySymbol = project.currency.symbol
        return formatter.string(from: NSNumber(value: value)) ?? "\(project.currency.symbol)0.00"
    }
}

// MARK: - Category Row
struct CategoryRow: View {
    @Binding var category: BudgetCategory
    let currency: Currency
    let totalBudget: Double
    let selectedIDs: Set<UUID>
    let onSelect: () -> Void
    let onDelete: (Set<UUID>) -> Void
    let onDuplicate: (Set<UUID>) -> Void
    @Binding var draggingID: UUID?
    @State private var showDeleteConfirmation = false

    private var isSelected: Bool {
        selectedIDs.contains(category.id)
    }

    // Right-click/context-menu actions target the whole current selection when this
    // row is part of it, or just this row alone otherwise - matches Finder: acting on
    // an item outside the current selection doesn't touch the rest of the selection.
    private var effectiveTargets: Set<UUID> {
        isSelected ? selectedIDs : [category.id]
    }

    private var percentage: String {
        guard totalBudget > 0 else { return "0%" }
        let pct = (category.totalEstimated / totalBudget) * 100
        return String(format: "%.1f%%", pct)
    }

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15))
                .foregroundColor(.secondary.opacity(0.5))
                .frame(width: 30)
                .contentShape(Rectangle())
                .onDrag {
                    draggingID = category.id
                    return NSItemProvider(object: category.id.uuidString as NSString)
                }

            HStack {
                InlineEditableText(text: $category.accountNumber, placeholder: "Acct", onActivate: onSelect, isRowSelected: isSelected)
                    .frame(width: 60, alignment: .leading)
                    .font(.system(.body, design: .monospaced))

                InlineEditableText(text: $category.name, placeholder: "Name", onActivate: onSelect, isRowSelected: isSelected)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formatCurrency(category.totalEstimated))
                    .frame(width: 100, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))

                Text(percentage)
                    .frame(width: 50, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)

                Text(formatCurrency(category.totalActual))
                    .frame(width: 100, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))

                Text(formatCurrency(category.totalRemaining))
                    .frame(width: 100, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(category.totalRemaining >= 0 ? .green : .red)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
        }
        .padding(.horizontal)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onDuplicate(effectiveTargets)
            } label: {
                Label(effectiveTargets.count > 1 ? "Duplicate \(effectiveTargets.count) Accounts" : "Duplicate Account", systemImage: "doc.on.doc")
            }

            Button(role: .destructive) {
                if NSEvent.modifierFlags.contains(.option) {
                    onDelete(effectiveTargets)
                } else {
                    showDeleteConfirmation = true
                }
            } label: {
                Label(effectiveTargets.count > 1 ? "Delete \(effectiveTargets.count) Accounts" : "Delete Account", systemImage: "trash")
            }
        }
        .confirmationDialog(
            effectiveTargets.count > 1 ? "Delete \(effectiveTargets.count) accounts?" : "Delete \u{201C}\(category.name)\u{201D}?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete(effectiveTargets) }
        } message: {
            Text(effectiveTargets.count > 1
                 ? "This removes the accounts and all their line items. Hold Option to skip this confirmation."
                 : "This removes the account and all its line items. Hold Option to skip this confirmation.")
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        formatter.currencySymbol = currency.symbol
        return formatter.string(from: NSNumber(value: value)) ?? "\(currency.symbol)0.00"
    }
}

// MARK: - Category Drop Delegate
//
// Standard SwiftUI onDrag/onDrop reordering pattern: draggingID is set as a side
// effect when a drag starts (in CategoryRow's .onDrag), and read/cleared here.
struct CategoryDropDelegate: DropDelegate {
    let item: BudgetCategory
    var categories: Binding<[BudgetCategory]>
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != item.id,
              let fromIndex = categories.wrappedValue.firstIndex(where: { $0.id == draggingID }),
              let toIndex = categories.wrappedValue.firstIndex(where: { $0.id == item.id })
        else { return }

        if fromIndex != toIndex {
            categories.wrappedValue.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
