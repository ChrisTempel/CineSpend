//
//  CategoryDetailView.swift
//  CineSpend
//
//  Detailed view of a budget category with line items
//

import SwiftUI

struct CategoryDetailView: View {
    @Binding var category: BudgetCategory
    let currency: Currency
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 10) {
                HStack {
                    Text("\(category.accountNumber) - \(category.name)")
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
                Text("DESCRIPTION")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("ESTIMATED")
                    .frame(width: 120, alignment: .trailing)
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("ACTUAL")
                    .frame(width: 120, alignment: .trailing)
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("REMAINING")
                    .frame(width: 120, alignment: .trailing)
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("")
                    .frame(width: 30)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Line Items
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(category.lineItems.indices, id: \.self) { index in
                        LineItemRow(
                            lineItem: $category.lineItems[index],
                            currency: currency,
                            onDelete: {
                                deleteLineItem(at: index)
                            },
                            onDuplicate: {
                                duplicateLineItem(at: index)
                            }
                        )
                        Divider()
                    }
                }
            }
            
            Divider()
            
            // Category Totals
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
    }
    
    private func addLineItem() {
        let newItem = LineItem(description: "New Line Item", estimated: 0, actual: 0)
        category.lineItems.append(newItem)
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
        category.lineItems.insert(duplicate, at: index + 1)
    }
    
    private func deleteLineItem(at index: Int) {
        category.lineItems.remove(at: index)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        formatter.currencySymbol = currency.symbol
        return formatter.string(from: NSNumber(value: value)) ?? "\(currency.symbol)0.00"
    }
}

// MARK: - Line Item Row
struct LineItemRow: View {
    @Binding var lineItem: LineItem
    let currency: Currency
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    @State private var showNotesField = false
    @State private var showEstimatedCalculator = false
    @State private var showActualCalculator = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Row
            HStack {
                TextField("Description", text: $lineItem.description)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Estimated - clickable to open calculator
                Button(action: { showEstimatedCalculator = true }) {
                    Text(formatCurrency(lineItem.estimated))
                        .frame(width: 110, alignment: .trailing)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.blue)
                        .underline()
                }
                .buttonStyle(.plain)
                .help("Click to calculate")
                
                // Actual - clickable to open calculator
                Button(action: { showActualCalculator = true }) {
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
        .sheet(isPresented: $showEstimatedCalculator) {
            UnitCalculatorView(
                lineItem: $lineItem,
                currency: currency,
                isPresented: $showEstimatedCalculator,
                mode: .estimated
            )
        }
        .sheet(isPresented: $showActualCalculator) {
            UnitCalculatorView(
                lineItem: $lineItem,
                currency: currency,
                isPresented: $showActualCalculator,
                mode: .actual
            )
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

// MARK: - Unit Calculator View
struct UnitCalculatorView: View {
    @Binding var lineItem: LineItem
    let currency: Currency
    @Binding var isPresented: Bool
    let mode: CalculatorMode
    
    enum CalculatorMode {
        case estimated, actual
        
        var title: String {
            switch self {
            case .estimated: return "Estimated Cost Calculator"
            case .actual: return "Actual Cost Calculator"
            }
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
                    ForEach(lineItem.units.indices, id: \.self) { index in
                        UnitRow(
                            unit: $lineItem.units[index],
                            currency: currency,
                            mode: mode,
                            onDelete: {
                                lineItem.units.remove(at: index)
                            }
                        )
                        Divider()
                    }
                }
            }
            
            Divider()
            
            // Bottom Bar: Add Unit + Total + Done
            HStack {
                Button(action: {
                    lineItem.units.append(UnitBreakdown(
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
                
                Button("Done") {
                    applyTotal()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .controlSize(.large)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 400)
    }
    
    private var calculatedTotal: Double {
        lineItem.units.reduce(0) { sum, unit in
            let rate = mode == .estimated ? unit.rate : unit.actualRate
            return sum + (unit.amount * unit.units * rate)
        }
    }
    
    private func applyTotal() {
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
            
            TextField("Amt", value: $unit.amount, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
            
            TextField("Units", value: $unit.units, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
            
            Text("×")
                .frame(width: 20, alignment: .center)
                .foregroundColor(.secondary)
            
            // Show appropriate rate field based on mode
            if mode == .estimated {
                TextField("Rate", value: $unit.rate, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            } else {
                TextField("Rate", value: $unit.actualRate, format: .number)
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
