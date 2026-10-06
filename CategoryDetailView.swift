//
//  CategoryDetailView.swift
//  CineSpend
//
//  Detailed view of a budget category with line items
//

import SwiftUI

// MARK: - Calculator Presenter
//
// The Unit Calculator is presented as a window-spanning overlay (see ContentView) rather
// than a native .sheet(), because AppKit sheets have no way to detect or react to a click
// on their dimmed backdrop. Presentation state lives here, injected as an environment
// object from ContentView (the window root), so a LineItemRow nested deep inside the
// category list can trigger a card that visually covers the whole window, not just itself.
final class CalculatorPresenter: ObservableObject {
    // Identifies the line item rather than storing a Binding to it directly: a Binding
    // captured here would freeze whatever value-type project/category snapshot was live
    // at the moment .present() was called, since - unlike a @Binding *parameter*, which
    // SwiftUI refreshes on every parent re-render - a Binding stored in a @Published
    // property never gets refreshed. ContentView turns these IDs into a Binding that
    // reads/writes projectManager.currentProject directly on every access, so there's
    // no snapshot to go stale.
    struct Request {
        var categoryID: UUID
        var lineItemID: UUID
        var currency: Currency
        var mode: UnitCalculatorView.CalculatorMode
    }

    @Published var active: Request?

    func present(categoryID: UUID, lineItemID: UUID, currency: Currency, mode: UnitCalculatorView.CalculatorMode) {
        active = Request(categoryID: categoryID, lineItemID: lineItemID, currency: currency, mode: mode)
    }

    func dismiss() {
        active = nil
    }
}

struct CategoryDetailView: View {
    @Binding var category: BudgetCategory
    let currency: Currency
    @EnvironmentObject var projectManager: ProjectManager
    @State private var draggingLineItemID: UUID?
    @State private var sort: ColumnSort<LineItemColumn>?
    @FocusState private var focusedDescriptionID: UUID?

    enum LineItemColumn {
        case order, description, estimated, actual, remaining
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 10) {
                HStack {
                    HStack(spacing: 8) {
                        InlineEditableText(text: $category.accountNumber, placeholder: "Acct")
                            .frame(width: 70)

                        InlineEditableText(text: $category.name, placeholder: "Name")
                    }
                    .font(.title2)
                    .fontWeight(.bold)

                    Spacer()
                    
                    Button(action: addLineItem) {
                        Label("Add Line Item", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Text("CATEGORY DETAIL")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Column Headers
            HStack {
                Text("").frame(width: 30) // aligns with the drag handle column below

                sortHeader("#", column: .order, width: 26, alignment: .trailing)
                Text("").frame(width: 14) // aligns with the disclosure triangle column below
                sortHeader("DESCRIPTION", column: .description, alignment: .leading)
                sortHeader("ESTIMATED", column: .estimated, width: 120, alignment: .trailing)
                sortHeader("ACTUAL", column: .actual, width: 120, alignment: .trailing)
                sortHeader("REMAINING", column: .remaining, width: 120, alignment: .trailing)

                Text("")
                    .frame(width: 30)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Line Items
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(category.lineItems.indices, id: \.self) { index in
                        LineItemRow(
                            lineItem: $category.lineItems[index],
                            currency: currency,
                            categoryID: category.id,
                            order: projectManager.originalOrder(categoryID: category.id, lineItemID: category.lineItems[index].id) ?? index + 1,
                            focusedDescriptionID: $focusedDescriptionID,
                            onDelete: {
                                deleteLineItem(at: index)
                            },
                            onDuplicate: {
                                duplicateLineItem(at: index)
                            },
                            onTabDescription: { forward in
                                moveDescriptionFocus(from: category.lineItems[index].id, forward: forward)
                            },
                            draggingID: $draggingLineItemID
                        )
                        .onDrop(of: [.text], delegate: LineItemDropDelegate(
                            item: category.lineItems[index],
                            lineItems: $category.lineItems,
                            draggingID: $draggingLineItemID
                        ))
                        Divider()
                    }
                }
            }

            Divider()

            // Category Totals - Subtotal/Contingency only shown once this category's
            // internal contingency is enabled; otherwise it's just Category Total, same
            // as any account that doesn't use the feature.
            if category.contingencyPercentage != nil {
                HStack {
                    Text("SUBTOTAL")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text(formatCurrency(category.lineItemsSubtotalEstimated))
                        .frame(width: 120, alignment: .trailing)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(formatCurrency(category.totalActual))
                        .frame(width: 120, alignment: .trailing)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(formatCurrency(category.lineItemsSubtotalEstimated - category.totalActual))
                        .frame(width: 120, alignment: .trailing)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("")
                        .frame(width: 30)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                HStack {
                    HStack(spacing: 4) {
                        Text("CONTINGENCY")
                            .font(.subheadline)

                        NumericField(value: Binding(
                            get: { category.contingencyPercentage ?? 0 },
                            set: { category.contingencyPercentage = $0 }
                        ))
                            .textFieldStyle(.plain)
                            .frame(width: 35)
                            .foregroundColor(.blue)

                        Text("%")
                            .font(.subheadline)
                    }

                    Spacer()

                    Text(formatCurrency(category.contingencyEstimated))
                        .frame(width: 120, alignment: .trailing)
                        .font(.system(.body, design: .monospaced))

                    Text("")
                        .frame(width: 120, alignment: .trailing)

                    Text(formatCurrency(category.contingencyEstimated))
                        .frame(width: 120, alignment: .trailing)
                        .font(.system(.body, design: .monospaced))

                    Text("")
                        .frame(width: 30)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)

                Divider()
            }

            HStack {
                Text("CATEGORY TOTAL")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Text(formatCurrency(category.totalEstimated))
                    .frame(width: 120, alignment: .trailing)
                    .font(.headline)
                    .fontWeight(.bold)

                Text(formatCurrency(category.totalActual))
                    .frame(width: 120, alignment: .trailing)
                    .font(.headline)
                    .fontWeight(.bold)

                Text(formatCurrency(category.totalRemaining))
                    .frame(width: 120, alignment: .trailing)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(category.totalRemaining >= 0 ? .green : .red)

                Text("")
                    .frame(width: 30)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .contextMenu {
            // First of what should grow into a set of category-scoped actions.
            Toggle("Enable Category Contingency", isOn: Binding(
                get: { category.contingencyPercentage != nil },
                set: { enabled in category.contingencyPercentage = enabled ? 10.0 : nil }
            ))
        }
    }
    
    private func addLineItem() {
        let newItem = LineItem(description: "New Line Item", estimated: 0, actual: 0)
        category.lineItems.append(newItem)
        projectManager.recordOriginalOrderIfNeeded(categoryID: category.id, lineItemIDs: [newItem.id])
    }

    private func duplicateLineItem(at index: Int) {
        let original = category.lineItems[index]
        var duplicate = LineItem(
            description: original.description + " (Copy)",
            estimated: original.estimated,
            actual: original.actual,
            notes: original.notes
        )
        // Copy all the units too
        duplicate.units = original.units
        duplicate.breakdownCollapsed = original.breakdownCollapsed
        category.lineItems.insert(duplicate, at: index + 1)
        projectManager.recordOriginalOrderIfNeeded(categoryID: category.id, lineItemIDs: [duplicate.id])
    }
    
    private func deleteLineItem(at index: Int) {
        category.lineItems.remove(at: index)
    }

    private func moveDescriptionFocus(from id: UUID, forward: Bool) {
        guard let index = category.lineItems.firstIndex(where: { $0.id == id }) else { return }
        let newIndex = forward ? index + 1 : index - 1
        guard category.lineItems.indices.contains(newIndex) else { return }
        focusedDescriptionID = category.lineItems[newIndex].id
    }

    @ViewBuilder
    private func sortHeader(_ title: String, column: LineItemColumn, width: CGFloat? = nil, alignment: Alignment) -> some View {
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

    private func applySort(_ column: LineItemColumn) {
        let newSort = ColumnSort.next(after: sort, tapped: column)
        sort = newSort

        let ascending = newSort.ascending
        switch column {
        case .order:
            category.lineItems.sort {
                let lhs = projectManager.originalOrder(categoryID: category.id, lineItemID: $0.id) ?? 0
                let rhs = projectManager.originalOrder(categoryID: category.id, lineItemID: $1.id) ?? 0
                return ascending ? lhs < rhs : lhs > rhs
            }
        case .description:
            category.lineItems.sort {
                let order = $0.description.localizedStandardCompare($1.description)
                return ascending ? order == .orderedAscending : order == .orderedDescending
            }
        case .estimated:
            category.lineItems.sort { ascending ? $0.estimated < $1.estimated : $0.estimated > $1.estimated }
        case .actual:
            category.lineItems.sort { ascending ? $0.actual < $1.actual : $0.actual > $1.actual }
        case .remaining:
            category.lineItems.sort { ascending ? $0.remaining < $1.remaining : $0.remaining > $1.remaining }
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

// MARK: - Line Item Drop Delegate
struct LineItemDropDelegate: DropDelegate {
    let item: LineItem
    var lineItems: Binding<[LineItem]>
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != item.id,
              let fromIndex = lineItems.wrappedValue.firstIndex(where: { $0.id == draggingID }),
              let toIndex = lineItems.wrappedValue.firstIndex(where: { $0.id == item.id })
        else { return }

        if fromIndex != toIndex {
            lineItems.wrappedValue.move(
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

// MARK: - Line Item Row
struct LineItemRow: View {
    @Binding var lineItem: LineItem
    let currency: Currency
    let categoryID: UUID
    let order: Int
    var focusedDescriptionID: FocusState<UUID?>.Binding
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onTabDescription: (Bool) -> Void
    @Binding var draggingID: UUID?
    @EnvironmentObject var calculatorPresenter: CalculatorPresenter
    @State private var showNotesField = false

    var body: some View {
        VStack(spacing: 0) {
            // Main Row
            HStack {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 30)
                    .contentShape(Rectangle())
                    .onDrag {
                        draggingID = lineItem.id
                        return NSItemProvider(object: lineItem.id.uuidString as NSString)
                    }

                Text("\(order)")
                    .frame(width: 26, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)

                // Disclosure triangle - only for line items that have a unit breakdown.
                // Flat-cost items get an empty slot so descriptions stay aligned.
                if hasBreakdown {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            lineItem.breakdownCollapsed.toggle()
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(lineItem.breakdownCollapsed ? 0 : 90))
                            .frame(width: 14, height: 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(lineItem.breakdownCollapsed ? "Show breakdown" : "Hide breakdown")
                } else {
                    Color.clear.frame(width: 14, height: 14)
                }

                TextField("Description", text: $lineItem.description)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focused(focusedDescriptionID, equals: lineItem.id)
                    .onKeyPress { press in
                        guard press.key == .tab else { return .ignored }
                        onTabDescription(!press.modifiers.contains(.shift))
                        return .handled
                    }

                // Estimated - clickable to open calculator
                Button(action: {
                    calculatorPresenter.present(categoryID: categoryID, lineItemID: lineItem.id, currency: currency, mode: .estimated)
                }) {
                    Text(formatCurrency(lineItem.estimated))
                        .frame(width: 110, alignment: .trailing)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.blue)
                        .underline()
                }
                .buttonStyle(.plain)
                .help("Click to calculate")

                // Actual - clickable to open calculator
                Button(action: {
                    calculatorPresenter.present(categoryID: categoryID, lineItemID: lineItem.id, currency: currency, mode: .actual)
                }) {
                    Text(formatCurrency(lineItem.actual))
                        .frame(width: 110, alignment: .trailing)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.blue)
                        .underline()
                }
                .buttonStyle(.plain)
                .help("Click to calculate")
                
                Text(formatCurrency(lineItem.remaining))
                    .frame(width: 120, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(lineItem.remaining >= 0 ? .green : .red)
                
                Menu {
                    Button(action: { showNotesField.toggle() }) {
                        Label(showNotesField ? "Hide Notes" : "Add Notes", systemImage: "note.text")
                    }
                    
                    Button(action: onDuplicate) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Unit breakdown preview (read-only; editing happens in the calculator).
            // Each child mirrors the main row's columns so values line up under
            // ESTIMATED and ACTUAL.
            if hasBreakdown && !lineItem.breakdownCollapsed {
                VStack(spacing: 0) {
                    ForEach(lineItem.units.indices, id: \.self) { i in
                        let unit = lineItem.units[i]
                        HStack {
                            Color.clear.frame(width: 30, height: 1)
                            Color.clear.frame(width: 26, height: 1)
                            Color.clear.frame(width: 14, height: 1)

                            HStack(spacing: 6) {
                                Text(unit.description.isEmpty ? "Untitled" : unit.description)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Text(formula(for: unit))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(formatCurrency(unit.estimatedSubtotal))
                                .frame(width: 110, alignment: .trailing)
                                .font(.system(.callout, design: .monospaced))

                            Text(formatCurrency(unit.actualSubtotal))
                                .frame(width: 110, alignment: .trailing)
                                .font(.system(.callout, design: .monospaced))

                            Color.clear.frame(width: 120, height: 1)
                            Color.clear.frame(width: 30, height: 1)
                        }
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 3)
                    }
                }
                .padding(.bottom, 6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
            }
            
            // Notes section
            if showNotesField {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Notes:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $lineItem.notes)
                        .frame(height: 60)
                        .font(.body)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            }
        }
    }
    
    private var hasBreakdown: Bool {
        !lineItem.units.isEmpty
    }

    // e.g. "1 × 10 × $500.00"
    private func formula(for unit: UnitBreakdown) -> String {
        "\(trimmed(unit.amount)) × \(trimmed(unit.units)) × \(formatCurrency(unit.rate))"
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.2f", value)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        formatter.currencySymbol = currency.symbol
        return formatter.string(from: NSNumber(value: value)) ?? "\(currency.symbol)0.00"
    }
}

// MARK: - Unit Calculator View
struct UnitCalculatorView: View {
    @Binding var lineItem: LineItem
    let currency: Currency
    let mode: CalculatorMode
    let maxSize: CGSize
    let onDismiss: () -> Void

    // Edits happen on a local copy so Cancel/background-tap can discard them.
    // Nothing is written back to lineItem until Done is pressed.
    @State private var workingUnits: [UnitBreakdown]

    // Shared across every UnitCalculatorView instance via UserDefaults, so resizing
    // one card changes the size the next one (for any line item) opens at.
    @AppStorage("unitCalculatorCardWidth") private var cardWidth: Double = 800
    @AppStorage("unitCalculatorCardHeight") private var cardHeight: Double = 500
    @State private var sizeAtDragStart: CGSize?

    private let minCardSize = CGSize(width: 600, height: 350)

    // The stored size is a preference, not a hard requirement - clamp what's actually
    // rendered to whatever the window currently offers, without overwriting the
    // preference, so a later window resize can restore the larger size.
    private var displaySize: CGSize {
        CGSize(
            width: min(max(cardWidth, minCardSize.width), max(maxSize.width, minCardSize.width)),
            height: min(max(cardHeight, minCardSize.height), max(maxSize.height, minCardSize.height))
        )
    }

    enum CalculatorMode {
        case estimated, actual

        var title: String {
            switch self {
            case .estimated: return "Estimated Cost Calculator"
            case .actual: return "Actual Cost Calculator"
            }
        }
    }

    init(lineItem: Binding<LineItem>, currency: Currency, mode: CalculatorMode, maxSize: CGSize, onDismiss: @escaping () -> Void) {
        self._lineItem = lineItem
        self.currency = currency
        self.mode = mode
        self.maxSize = maxSize
        self.onDismiss = onDismiss

        let item = lineItem.wrappedValue
        if item.units.isEmpty && (item.estimated != 0 || item.actual != 0) {
            // A flat value with no breakdown - represent it as a single row so the
            // calculator reflects reality instead of showing an empty, misleading $0
            // total for a line item that actually has money in it.
            self._workingUnits = State(initialValue: [
                UnitBreakdown(description: item.description, amount: 1, units: 1,
                              rate: item.estimated, actualRate: item.actual)
            ])
        } else {
            self._workingUnits = State(initialValue: item.units)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(lineItem.description)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Text(mode.title)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Column Headers
            HStack(spacing: 8) {
                Text("Description")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.caption)
                    .fontWeight(.bold)

                Text("Amt")
                    .frame(width: 60, alignment: .trailing)
                    .font(.caption)
                    .fontWeight(.bold)

                Text("Units")
                    .frame(width: 60, alignment: .trailing)
                    .font(.caption)
                    .fontWeight(.bold)

                Text("×")
                    .frame(width: 20, alignment: .center)
                    .font(.caption)
                    .fontWeight(.bold)

                Text("Rate")
                    .frame(width: 80, alignment: .trailing)
                    .font(.caption)
                    .fontWeight(.bold)

                Text("Subtotal")
                    .frame(width: 100, alignment: .trailing)
                    .font(.caption)
                    .fontWeight(.bold)

                Text("")
                    .frame(width: 30)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Unit Rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(workingUnits.indices, id: \.self) { index in
                        UnitRow(
                            unit: $workingUnits[index],
                            currency: currency,
                            mode: mode,
                            onDelete: {
                                workingUnits.remove(at: index)
                            }
                        )
                        Divider()
                    }
                }
            }

            Divider()

            // Bottom Bar: Add Unit + Total + Cancel/Done
            HStack {
                Button(action: {
                    workingUnits.append(UnitBreakdown(
                        description: "New Unit",
                        amount: 1,
                        units: 1,
                        rate: 0,
                        actualRate: 0
                    ))
                }) {
                    Label("Add Unit", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)

                Spacer()

                // Show total
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total:")
                        .font(.headline)
                    Text(formatCurrency(calculatedTotal))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                }

                Spacer()
                    .frame(width: 40)

                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)

                Button("Done") {
                    applyTotal()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 24, y: 8)
        // Swallow taps so they don't fall through to the backdrop's cancel gesture behind it.
        .onTapGesture {}
        .overlay(alignment: .bottomTrailing) { resizeHandle }
    }

    // Dragging the corner resizes from the card's center: growth on this edge is
    // mirrored on the opposite edge (via the ×2 factor below), so the card stays
    // centered as it grows/shrinks, capped at the window's current size.
    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary.opacity(0.5))
            .padding(8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        let start = sizeAtDragStart ?? CGSize(width: cardWidth, height: cardHeight)
                        if sizeAtDragStart == nil { sizeAtDragStart = start }

                        let newWidth = start.width + value.translation.width * 2
                        let newHeight = start.height + value.translation.height * 2

                        cardWidth = min(max(newWidth, minCardSize.width), max(maxSize.width, minCardSize.width))
                        cardHeight = min(max(newHeight, minCardSize.height), max(maxSize.height, minCardSize.height))
                    }
                    .onEnded { _ in
                        sizeAtDragStart = nil
                    }
            )
    }

    private var calculatedTotal: Double {
        workingUnits.reduce(0) { sum, unit in
            let rate = mode == .estimated ? unit.rate : unit.actualRate
            return sum + (unit.amount * unit.units * rate)
        }
    }

    private func applyTotal() {
        lineItem.units = workingUnits
        switch mode {
        case .estimated:
            lineItem.estimated = calculatedTotal
        case .actual:
            lineItem.actual = calculatedTotal
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

// MARK: - Unit Row
struct UnitRow: View {
    @Binding var unit: UnitBreakdown
    let currency: Currency
    let mode: UnitCalculatorView.CalculatorMode
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("Description", text: $unit.description)
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity)
            
            NumericField(value: $unit.amount)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)

            NumericField(value: $unit.units)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)

            Text("×")
                .frame(width: 20, alignment: .center)
                .foregroundColor(.secondary)

            // Show appropriate rate field based on mode
            if mode == .estimated {
                NumericField(value: $unit.rate)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            } else {
                NumericField(value: $unit.actualRate)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            
            // Show subtotal
            Text(formatCurrency(subtotal))
                .frame(width: 100, alignment: .trailing)
                .font(.system(.body, design: .monospaced))
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 30)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var subtotal: Double {
        let rate = mode == .estimated ? unit.rate : unit.actualRate
        return unit.amount * unit.units * rate
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        formatter.currencySymbol = currency.symbol
        return formatter.string(from: NSNumber(value: value)) ?? "\(currency.symbol)0.00"
    }
}
