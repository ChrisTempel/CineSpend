//
//  TopSheetView.swift
//  CineSpend
//
//  Top sheet showing all budget categories with totals
//

import SwiftUI

struct TopSheetView: View {
    @Binding var project: Project
    @Binding var selectedCategoryID: UUID?
    let updateTrigger: UUID
    @State private var editingProjectName = false
    
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
                
                Text("BUDGET TOP SHEET")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
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
                Text("ACCT")
                    .frame(width: 60, alignment: .leading)
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("CATEGORY")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("ESTIMATED")
                    .frame(width: 100, alignment: .trailing)
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("%")
                    .frame(width: 50, alignment: .trailing)
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("ACTUAL")
                    .frame(width: 100, alignment: .trailing)
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("REMAINING")
                    .frame(width: 100, alignment: .trailing)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Category List (excluding Contingency)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(project.categories.indices, id: \.self) { index in
                        // Skip contingency - it's shown separately below
                        if project.categories[index].accountNumber != "19000" {
                            CategoryRow(
                                category: $project.categories[index],
                                totalBudget: subtotalEstimated,
                                isSelected: project.categories[index].id == selectedCategoryID,
                                onSelect: {
                                    selectedCategoryID = project.categories[index].id
                                }
                            )
                            Divider()
                        }
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
            
            // Contingency Row
            if let contingencyCategory = project.categories.first(where: { $0.accountNumber == "19000" }) {
                HStack {
                    Text("19000")
                        .frame(width: 60, alignment: .leading)
                        .font(.system(.body, design: .monospaced))
                    
                    HStack(spacing: 4) {
                        Text("Contingency")
                            .frame(alignment: .leading)
                        
                        TextField("", value: $project.contingencyPercentage, format: .number)
                            .textFieldStyle(.plain)
                            .frame(width: 35)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.blue)
                        
                        Text("%")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(formatCurrency(contingencyCategory.totalEstimated))
                        .frame(width: 100, alignment: .trailing)
                        .font(.system(.body, design: .monospaced))
                    
                    Text("")
                        .frame(width: 50, alignment: .trailing)
                    
                    Text(formatCurrency(contingencyCategory.totalActual))
                        .frame(width: 100, alignment: .trailing)
                        .font(.system(.body, design: .monospaced))
                    
                    Text(formatCurrency(contingencyCategory.totalRemaining))
                        .frame(width: 100, alignment: .trailing)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(contingencyCategory.totalRemaining >= 0 ? .green : .red)
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
        .onChange(of: project.contingencyPercentage) { _ in
            autoUpdateContingency()
        }
        .onChange(of: updateTrigger) { _ in
            autoUpdateContingency()
        }
        .onChange(of: subtotalEstimated) { newValue in
            autoUpdateContingency()
        }
        .onAppear {
            autoUpdateContingency()
        }
    }
    
    // Subtotal = everything EXCEPT contingency (19000)
    private var subtotalEstimated: Double {
        project.categories
            .filter { $0.accountNumber != "19000" }
            .reduce(0) { $0 + $1.totalEstimated }
    }
    
    private var subtotalActual: Double {
        project.categories
            .filter { $0.accountNumber != "19000" }
            .reduce(0) { $0 + $1.totalActual }
    }
    
    private var subtotalRemaining: Double {
        subtotalEstimated - subtotalActual
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func autoUpdateContingency() {
        // Find Contingency category (19000)
        guard let contingencyIndex = project.categories.firstIndex(where: { $0.accountNumber == "19000" }),
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
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Category Row
struct CategoryRow: View {
    @Binding var category: BudgetCategory
    let totalBudget: Double
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var percentage: String {
        guard totalBudget > 0 else { return "0%" }
        let pct = (category.totalEstimated / totalBudget) * 100
        return String(format: "%.1f%%", pct)
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(category.accountNumber)
                    .frame(width: 60, alignment: .leading)
                    .font(.system(.body, design: .monospaced))
                
                Text(category.name)
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
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}
