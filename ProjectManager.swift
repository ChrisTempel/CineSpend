//
//  ProjectManager.swift
//  CineSpend
//
//  Manages project saving, loading, and PDF export
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
import AppKit

class ProjectManager: ObservableObject {
    @Published var currentProject: Project?
    @Published var currentFileURL: URL?
    
    // MARK: - Project Management
    
    func createNewProject() {
        DispatchQueue.main.async {
            // Create alert for project setup
            let alert = NSAlert()
            alert.messageText = "New Film Budget"
            alert.informativeText = "Choose your project currency:"
            alert.alertStyle = .informational
            
            // Create accessory view with currency picker
            let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
            
            // Currency label
            let currencyLabel = NSTextField(labelWithString: "Currency:")
            currencyLabel.frame = NSRect(x: 0, y: 30, width: 80, height: 20)
            accessoryView.addSubview(currencyLabel)
            
            // Currency popup
            let currencyPopup = NSPopUpButton(frame: NSRect(x: 85, y: 28, width: 215, height: 25))
            for currency in Currency.allCases {
                currencyPopup.addItem(withTitle: currency.displayName)
            }
            currencyPopup.selectItem(at: 0) // Default to USD
            accessoryView.addSubview(currencyPopup)
            
            // Project name label
            let nameLabel = NSTextField(labelWithString: "Project Name:")
            nameLabel.frame = NSRect(x: 0, y: 0, width: 80, height: 20)
            accessoryView.addSubview(nameLabel)
            
            // Project name field
            let nameField = NSTextField(frame: NSRect(x: 85, y: 0, width: 215, height: 22))
            nameField.stringValue = "Untitled Film Budget"
            nameField.placeholderString = "Enter project name"
            accessoryView.addSubview(nameField)
            
            alert.accessoryView = accessoryView
            alert.addButton(withTitle: "Create")
            alert.addButton(withTitle: "Cancel")
            
            // Make name field first responder
            alert.window.initialFirstResponder = nameField
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                let selectedCurrency = Currency.allCases[currencyPopup.indexOfSelectedItem]
                let projectName = nameField.stringValue.isEmpty ? "Untitled Film Budget" : nameField.stringValue
                
                let newProject = Project(name: projectName, currency: selectedCurrency)
                self.currentProject = newProject
                self.currentFileURL = nil
            }
        }
    }
    
    func saveCurrentProject() {
        guard var project = currentProject else { return }
        
        project.updateModifiedDate()
        currentProject = project
        
        if let url = currentFileURL {
            // Save to existing file
            saveProject(project, to: url)
        } else {
            // Show save panel on main thread
            DispatchQueue.main.async {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [UTType(filenameExtension: "cinespend")!]
                panel.nameFieldStringValue = project.name
                panel.canCreateDirectories = true
                
                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        self.saveProject(project, to: url)
                        self.currentFileURL = url
                    }
                }
            }
        }
    }
    
    private func saveProject(_ project: Project, to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(project)
            try data.write(to: url)
        } catch {
            print("Error saving project: \(error)")
        }
    }
    
    func openProject() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [UTType(filenameExtension: "cinespend")!]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            
            panel.begin { response in
                if response == .OK, let url = panel.urls.first {
                    self.loadProject(from: url)
                }
            }
        }
    }
    
    private func loadProject(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let project = try decoder.decode(Project.self, from: data)
            currentProject = project
            currentFileURL = url
        } catch {
            print("Error loading project: \(error)")
        }
    }
    
    // MARK: - PDF Export
    
    func exportToPDF() {
        guard let project = currentProject else { return }
        
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = "\(project.name) - Budget.pdf"
            panel.canCreateDirectories = true
            
            // Add accessory view with checkbox for unit breakdowns
            let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 30))
            let checkbox = NSButton(checkboxWithTitle: "Include unit breakdowns in detail pages", target: nil, action: nil)
            checkbox.frame = NSRect(x: 0, y: 0, width: 300, height: 30)
            checkbox.state = .on  // Default to checked
            accessoryView.addSubview(checkbox)
            panel.accessoryView = accessoryView
            
            panel.begin { [weak self] response in
                guard let self = self else { return }
                if response == .OK, let url = panel.url {
                    let includeUnitBreakdowns = (checkbox.state == .on)
                    // Generate PDF on background thread
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.generatePDF(for: project, to: url, includeUnitBreakdowns: includeUnitBreakdowns)
                    }
                }
            }
        }
    }
    
    private func generatePDF(for project: Project, to url: URL, includeUnitBreakdowns: Bool = true) {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        
        // Create PDF context with proper initialization
        var mediaBox = pageRect
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            print("Could not create PDF context")
            return
        }
        
        // Top Sheet
        pdfContext.beginPDFPage(nil)
        drawTopSheet(project: project, in: pdfContext, pageSize: pageRect.size)
        pdfContext.endPDFPage()
        
        // Detail Pages
        for category in project.categories {
            pdfContext.beginPDFPage(nil)
            drawCategoryDetail(category: category, projectName: project.name, currency: project.currency, in: pdfContext, pageSize: pageRect.size, includeUnitBreakdowns: includeUnitBreakdowns)
            pdfContext.endPDFPage()
        }
        
        pdfContext.closePDF()
    }
    
    private func drawTopSheet(project: Project, in context: CGContext, pageSize: CGSize) {
        let margin: CGFloat = 50
        var y: CGFloat = pageSize.height - margin // Start from top
        
        // Title
        let titleHeight = drawText("BUDGET TOP SHEET", at: CGPoint(x: pageSize.width / 2, y: y), 
                      fontSize: 24, bold: true, centered: true, in: context)
        y -= (titleHeight + 10)
        
        // Project Name
        let nameHeight = drawText(project.name, at: CGPoint(x: pageSize.width / 2, y: y), 
                      fontSize: 18, bold: false, centered: true, in: context)
        y -= (nameHeight + 20)
        
        // Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateStr = "Date: \(dateFormatter.string(from: project.dateModified))"
        let dateHeight = drawText(dateStr, at: CGPoint(x: margin, y: y), fontSize: 10, in: context)
        y -= (dateHeight + 5)
        
        // Prepared By
        let preparedBy = project.preparedBy.isEmpty ? "_______________________" : project.preparedBy
        let preparedByHeight = drawText("Prepared By: \(preparedBy)", at: CGPoint(x: margin, y: y), fontSize: 10, in: context)
        y -= (preparedByHeight + 25)
        
        // Headers
        drawText("ACCT", at: CGPoint(x: margin, y: y), fontSize: 10, bold: true, in: context)
        drawText("CATEGORY", at: CGPoint(x: margin + 60, y: y), fontSize: 10, bold: true, in: context)
        drawText("ESTIMATED", at: CGPoint(x: pageSize.width - margin - 240, y: y), fontSize: 10, bold: true, in: context)
        drawText("ACTUAL", at: CGPoint(x: pageSize.width - margin - 160, y: y), fontSize: 10, bold: true, in: context)
        drawText("REMAINING", at: CGPoint(x: pageSize.width - margin - 80, y: y), fontSize: 10, bold: true, in: context)
        y -= 20
        
        // Line
        drawLine(from: CGPoint(x: margin, y: y), to: CGPoint(x: pageSize.width - margin, y: y), in: context)
        y -= 15  // Increased from 10 to 15 for more spacing
        
        // Categories (excluding contingency)
        let subtotalEstimated = project.categories.filter { $0.accountNumber != "19000" }.reduce(0) { $0 + $1.totalEstimated }
        let subtotalActual = project.categories.filter { $0.accountNumber != "19000" }.reduce(0) { $0 + $1.totalActual }
        let subtotalRemaining = subtotalEstimated - subtotalActual
        
        for category in project.categories {
            if category.accountNumber == "19000" { continue } // Skip contingency - show separately
            if y < margin + 100 { break } // Stop if we're running out of space
            
            drawText(category.accountNumber, at: CGPoint(x: margin, y: y), fontSize: 10, in: context)
            drawText(category.name, at: CGPoint(x: margin + 60, y: y), fontSize: 10, in: context)
            drawText(formatCurrency(category.totalEstimated, currency: project.currency), at: CGPoint(x: pageSize.width - margin - 240, y: y), fontSize: 10, in: context)
            drawText(formatCurrency(category.totalActual, currency: project.currency), at: CGPoint(x: pageSize.width - margin - 160, y: y), fontSize: 10, in: context)
            drawText(formatCurrency(category.totalRemaining, currency: project.currency), at: CGPoint(x: pageSize.width - margin - 80, y: y), fontSize: 10, in: context)
            y -= 15
        }
        
        y -= 5
        drawLine(from: CGPoint(x: margin, y: y), to: CGPoint(x: pageSize.width - margin, y: y), in: context)
        y -= 12
        
        // Subtotal
        drawText("SUBTOTAL", at: CGPoint(x: margin + 60, y: y), fontSize: 10, bold: true, in: context)
        drawText(formatCurrency(subtotalEstimated, currency: project.currency), at: CGPoint(x: pageSize.width - margin - 240, y: y), fontSize: 10, bold: true, in: context)
        drawText(formatCurrency(subtotalActual, currency: project.currency), at: CGPoint(x: pageSize.width - margin - 160, y: y), fontSize: 10, bold: true, in: context)
        drawText(formatCurrency(subtotalRemaining, currency: project.currency), at: CGPoint(x: pageSize.width - margin - 80, y: y), fontSize: 10, bold: true, in: context)
        y -= 15
        
        // Contingency (dynamic %)
        if let contingency = project.categories.first(where: { $0.accountNumber == "19000" }) {
            let percentText = project.contingencyPercentage == floor(project.contingencyPercentage) 
                ? String(format: "%.0f", project.contingencyPercentage)
                : String(format: "%.1f", project.contingencyPercentage)
            
            drawText("19000", at: CGPoint(x: margin, y: y), fontSize: 10, in: context)
            drawText("Contingency (\(percentText)%)", at: CGPoint(x: margin + 60, y: y), fontSize: 10, in: context)
            drawText(formatCurrency(contingency.totalEstimated, currency: project.currency), at: CGPoint(x: pageSize.width - margin - 240, y: y), fontSize: 10, in: context)
            drawText(formatCurrency(contingency.totalActual, currency: project.currency), at: CGPoint(x: pageSize.width - margin - 160, y: y), fontSize: 10, in: context)
            drawText(formatCurrency(contingency.totalRemaining, currency: project.currency), at: CGPoint(x: pageSize.width - margin - 80, y: y), fontSize: 10, in: context)
            y -= 15
        }
        
        y -= 5
        drawLine(from: CGPoint(x: margin, y: y), to: CGPoint(x: pageSize.width - margin, y: y), in: context, width: 2)
        y -= 18  // Increased spacing before TOTAL row
        
        // Grand Total
        drawText("TOTAL", at: CGPoint(x: margin + 60, y: y), fontSize: 11, bold: true, in: context)
        drawText(formatCurrency(project.totalEstimated, currency: project.currency), at: CGPoint(x: pageSize.width - margin - 240, y: y), fontSize: 11, bold: true, in: context)
        drawText(formatCurrency(project.totalActual, currency: project.currency), at: CGPoint(x: pageSize.width - margin - 160, y: y), fontSize: 11, bold: true, in: context)
        drawText(formatCurrency(project.totalRemaining, currency: project.currency), at: CGPoint(x: pageSize.width - margin - 80, y: y), fontSize: 11, bold: true, in: context)
    }
    
    private func drawCategoryDetail(category: BudgetCategory, projectName: String, currency: Currency, in context: CGContext, pageSize: CGSize, includeUnitBreakdowns: Bool) {
        let margin: CGFloat = 50
        var y: CGFloat = pageSize.height - margin
        
        // Header
        let headerHeight = drawText("\(category.accountNumber) - \(category.name)", at: CGPoint(x: margin, y: y), 
                      fontSize: 16, bold: true, in: context)
        y -= (headerHeight + 25)
        
        // Project name
        let projectHeight = drawText(projectName, at: CGPoint(x: margin, y: y), fontSize: 10, in: context)
        y -= (projectHeight + 20)
        
        // Column headers
        drawText("DESCRIPTION", at: CGPoint(x: margin, y: y), fontSize: 10, bold: true, in: context)
        drawText("ESTIMATED", at: CGPoint(x: pageSize.width - margin - 240, y: y), fontSize: 10, bold: true, in: context)
        drawText("ACTUAL", at: CGPoint(x: pageSize.width - margin - 160, y: y), fontSize: 10, bold: true, in: context)
        drawText("REMAINING", at: CGPoint(x: pageSize.width - margin - 80, y: y), fontSize: 10, bold: true, in: context)
        y -= 20
        
        drawLine(from: CGPoint(x: margin, y: y), to: CGPoint(x: pageSize.width - margin, y: y), in: context)
        y -= 15  // Increased from 10 to 15 for more spacing
        
        // Line items
        for item in category.lineItems {
            if y < margin + 50 { break }
            
            drawText(item.description, at: CGPoint(x: margin, y: y), fontSize: 10, in: context)
            drawText(formatCurrency(item.estimated, currency: currency), at: CGPoint(x: pageSize.width - margin - 240, y: y), fontSize: 10, in: context)
            drawText(formatCurrency(item.actual, currency: currency), at: CGPoint(x: pageSize.width - margin - 160, y: y), fontSize: 10, in: context)
            drawText(formatCurrency(item.remaining, currency: currency), at: CGPoint(x: pageSize.width - margin - 80, y: y), fontSize: 10, in: context)
            y -= 15
            
            // Unit breakdowns (if enabled and present)
            if includeUnitBreakdowns && !item.units.isEmpty && y > margin + 80 {
                for unit in item.units {
                    if y < margin + 50 { break }
                    
                    // Format: "  Camera Body: 1 × 10 days × $500 = $5,000"
                    let amtStr = unit.amount == floor(unit.amount) ? String(format: "%.0f", unit.amount) : String(format: "%.1f", unit.amount)
                    let unitsStr = unit.units == floor(unit.units) ? String(format: "%.0f", unit.units) : String(format: "%.1f", unit.units)
                    let rateStr = formatCurrency(unit.rate, currency: currency)
                    let totalStr = formatCurrency(unit.amount * unit.units * unit.rate, currency: currency)
                    
                    let unitLine = "    \(unit.description): \(amtStr) × \(unitsStr) × \(rateStr) = \(totalStr)"
                    let unitHeight = drawText(unitLine, at: CGPoint(x: margin + 10, y: y), fontSize: 8, in: context)
                    y -= (unitHeight + 3)
                }
                y -= 5  // Extra spacing after unit breakdowns
            }
            
            if !item.notes.isEmpty && y > margin + 50 {
                let notesHeight = drawText("  Note: \(item.notes)", at: CGPoint(x: margin + 10, y: y), fontSize: 9, in: context)
                y -= (notesHeight + 5)
            }
        }
        
        y -= 10
        drawLine(from: CGPoint(x: margin, y: y), to: CGPoint(x: pageSize.width - margin, y: y), in: context, width: 2)
        y -= 15  // Increased from 10 to 15 for more spacing
        
        // Category total
        drawText("CATEGORY TOTAL", at: CGPoint(x: margin, y: y), fontSize: 11, bold: true, in: context)
        drawText(formatCurrency(category.totalEstimated, currency: currency), at: CGPoint(x: pageSize.width - margin - 240, y: y), fontSize: 11, bold: true, in: context)
        drawText(formatCurrency(category.totalActual, currency: currency), at: CGPoint(x: pageSize.width - margin - 160, y: y), fontSize: 11, bold: true, in: context)
        drawText(formatCurrency(category.totalRemaining, currency: currency), at: CGPoint(x: pageSize.width - margin - 80, y: y), fontSize: 11, bold: true, in: context)
    }
    
    // MARK: - PDF Drawing Helpers
    
    @discardableResult
    private func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat, bold: Bool = false, centered: Bool = false, in context: CGContext) -> CGFloat {
        let font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()
        
        let drawPoint: CGPoint
        if centered {
            drawPoint = CGPoint(x: point.x - size.width / 2, y: point.y)
        } else {
            drawPoint = point
        }
        
        // Save the graphics state
        context.saveGState()
        
        // No transformation needed - just draw normally
        let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
        let textRect = CGRect(x: drawPoint.x, y: drawPoint.y, width: size.width, height: size.height)
        let path = CGPath(rect: textRect, transform: nil)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, attributedString.length), path, nil)
        
        CTFrameDraw(frame, context)
        
        // Restore the graphics state
        context.restoreGState()
        
        return size.height
    }
    
    private func drawLine(from: CGPoint, to: CGPoint, in context: CGContext, width: CGFloat = 1) {
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(width)
        context.move(to: from)
        context.addLine(to: to)
        context.strokePath()
    }
    
    private func formatCurrency(_ value: Double, currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        formatter.currencySymbol = currency.symbol
        return formatter.string(from: NSNumber(value: value)) ?? "\(currency.symbol)0.00"
    }
}
