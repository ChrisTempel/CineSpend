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
    @Published private(set) var recentFileURLs: [URL] = []

    // Lives here (not as local @State in ContentView) so CineSpendApp.swift's .commands,
    // which only has access to projectManager, can know which category the Category menu
    // should act on.
    @Published var selectedCategoryID: UUID?

    // The app owns and exports this UTI (see Info.plist's UTExportedTypeDeclarations).
    // Looking it up via UTType(filenameExtension:)! instead would force-unwrap a nil
    // and crash if Launch Services hasn't (re)indexed the app yet - this exported-type
    // initializer is non-failable and doesn't depend on that timing at all.
    private static let cinespendType = UTType(exportedAs: "com.cinespend.project")

    init() {
        refreshRecentFiles()
    }

    // MARK: - Line Item Original Order
    //
    // A purely in-memory reference for the "#" column in CategoryDetailView: fixed at
    // the moment a line item is first seen (file load, new project, or creation), and
    // never updated afterward, so dragging/sorting a category's line items around never
    // changes it - clicking the "#" header can always restore file order. Deliberately
    // not part of Project/BudgetCategory/LineItem, so it never touches the file format.
    @Published private(set) var lineItemOriginalOrder: [UUID: [UUID: Int]] = [:]

    func recordOriginalOrderIfNeeded(categoryID: UUID, lineItemIDs: [UUID]) {
        var perCategory = lineItemOriginalOrder[categoryID] ?? [:]
        var nextOrder = (perCategory.values.max() ?? 0) + 1
        for id in lineItemIDs where perCategory[id] == nil {
            perCategory[id] = nextOrder
            nextOrder += 1
        }
        lineItemOriginalOrder[categoryID] = perCategory
    }

    func originalOrder(categoryID: UUID, lineItemID: UUID) -> Int? {
        lineItemOriginalOrder[categoryID]?[lineItemID]
    }

    private func recordOriginalOrder(for project: Project) {
        lineItemOriginalOrder.removeAll()
        for category in project.categories {
            recordOriginalOrderIfNeeded(categoryID: category.id, lineItemIDs: category.lineItems.map(\.id))
        }
    }

    // MARK: - Category-Scoped Actions
    //
    // Backs the "Category" menu bar commands, which only know the selected category's
    // ID (via selectedCategoryID) rather than holding a Binding the way a view does.
    // CategoryDetailView's own context menu toggles contingencyPercentage directly on
    // its Binding<BudgetCategory> instead of going through these - same end effect.

    var selectedCategory: BudgetCategory? {
        guard let id = selectedCategoryID else { return nil }
        return currentProject?.categories.first(where: { $0.id == id })
    }

    func setCategoryContingency(categoryID: UUID, enabled: Bool) {
        guard var project = currentProject,
              let index = project.categories.firstIndex(where: { $0.id == categoryID }) else { return }
        project.categories[index].contingencyPercentage = enabled ? 10.0 : nil
        currentProject = project
    }

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
                self.recordOriginalOrder(for: newProject)
            }
        }
    }
    
    /// Cmd+S. Writes to the already-open file, or falls through to Save As if this
    /// project has never been saved.
    func saveCurrentProject() {
        guard let project = currentProject else { return }
        if let url = currentFileURL {
            write(project, to: url)
        } else {
            saveCurrentProjectAs()
        }
    }

    /// Cmd+Shift+S. Always prompts for a location, even if the project already has a file.
    func saveCurrentProjectAs() {
        guard let project = currentProject else { return }
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [Self.cinespendType]
            panel.nameFieldStringValue = project.name
            panel.canCreateDirectories = true

            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                self.write(project, to: url)
                self.currentFileURL = url
            }
        }
    }

    /// Discards in-memory changes and reloads currentFileURL from disk, after confirming.
    func revertToSaved() {
        guard let url = currentFileURL else { return }
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Revert to Saved?"
            alert.informativeText = "This will discard any changes made since \u{201C}\(url.lastPathComponent)\u{201D} was last saved."
            alert.addButton(withTitle: "Revert")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            self.loadProject(from: url)
        }
    }

    private func write(_ project: Project, to url: URL) {
        var updated = project
        updated.updateModifiedDate()
        currentProject = updated

        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(updated)
            try data.write(to: url, options: .atomic)
            noteRecentFile(url)
        } catch {
            presentError(title: "Couldn\u{2019}t Save \u{201C}\(updated.name)\u{201D}", error)
        }
    }

    func openProject() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [Self.cinespendType]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false

            panel.begin { response in
                guard response == .OK, let url = panel.urls.first else { return }
                self.loadProject(from: url)
            }
        }
    }

    /// Also used by Open Recent and Revert to Saved, not just the Open panel.
    func loadProject(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(Project.self, from: data)
            let (project, migrated) = migrateLegacyContingency(decoded)

            currentFileURL = url
            recordOriginalOrder(for: project)
            noteRecentFile(url)

            if migrated {
                // Upgrades the file on disk right away, so this heuristic only ever
                // has to run once per file - every later open sees isProjectContingency
                // already set correctly and doesn't need to guess from accountNumber.
                write(project, to: url)
            } else {
                currentProject = project
            }
        } catch {
            presentError(title: "Couldn\u{2019}t Open \u{201C}\(url.lastPathComponent)\u{201D}", error)
        }
    }

    // MARK: - Legacy Migration
    //
    // BudgetCategory.isProjectContingency didn't exist before this file format version;
    // its custom decoder (see Models.swift) tolerates a missing key by defaulting to
    // false so old files decode at all, but that alone would silently lose which
    // category used to be the contingency. This recovers it using the old convention
    // (accountNumber == "19000") - only as a one-time migration, never as ongoing
    // identification - and the caller resaves immediately so it doesn't need to run again.

    private func migrateLegacyContingency(_ project: Project) -> (Project, migrated: Bool) {
        var project = project
        guard !project.categories.contains(where: { $0.isProjectContingency }),
              let legacyIndex = project.categories.firstIndex(where: { $0.accountNumber == "19000" })
        else { return (project, false) }

        project.categories[legacyIndex].isProjectContingency = true
        return (project, true)
    }

    // MARK: - Recent Files
    //
    // NSDocumentController's recent-documents list is the standard, Apple-provided
    // mechanism for this - it persists across launches and correctly handles sandboxed
    // security-scoped access on its own, so there's no bookmark bookkeeping to hand-roll.
    // Mirrored into a @Published property so SwiftUI's Commands (which observe
    // ProjectManager) rebuild the Open Recent menu reactively.

    private func refreshRecentFiles() {
        recentFileURLs = NSDocumentController.shared.recentDocumentURLs
    }

    private func noteRecentFile(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        refreshRecentFiles()
    }

    func clearRecentFiles() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        refreshRecentFiles()
    }

    private func presentError(title: String, _ error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = title
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
    
    // MARK: - Spreadsheet Export

    private static let xlsxType = UTType(importedAs: "org.openxmlformats.spreadsheetml.sheet")

    // Order here is also the order/default shown in the export panel's Format popup.
    private static let spreadsheetFormatOrder: [SpreadsheetFormat] = [.xlsx, .csv, .json]

    private static func contentType(for format: SpreadsheetFormat) -> UTType {
        switch format {
        case .csv: return .commaSeparatedText
        case .xlsx: return xlsxType
        case .json: return .json
        }
    }

    // NSPopUpButton's target is weak, so this needs a strong owner for the panel's
    // lifetime. ProjectManager isn't NSObject-derived (it's an ObservableObject), so
    // the @objc action target has to live on a small helper object instead.
    private final class SpreadsheetFormatPicker: NSObject {
        let panel: NSSavePanel
        let formats: [SpreadsheetFormat]

        init(panel: NSSavePanel, formats: [SpreadsheetFormat]) {
            self.panel = panel
            self.formats = formats
        }

        @objc func formatChanged(_ sender: NSPopUpButton) {
            let format = formats[sender.indexOfSelectedItem]
            panel.allowedContentTypes = [ProjectManager.contentType(for: format)]
        }
    }

    private var spreadsheetFormatPicker: SpreadsheetFormatPicker?

    func exportToSpreadsheet() {
        guard let project = currentProject else { return }

        DispatchQueue.main.async {
            let panel = NSSavePanel()
            let formats = Self.spreadsheetFormatOrder
            panel.allowedContentTypes = [Self.contentType(for: formats[0])]
            panel.nameFieldStringValue = project.name
            panel.canCreateDirectories = true

            let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 30))
            let label = NSTextField(labelWithString: "Format:")
            label.frame = NSRect(x: 0, y: 6, width: 50, height: 20)
            accessoryView.addSubview(label)

            let popup = NSPopUpButton(frame: NSRect(x: 55, y: 2, width: 180, height: 25))
            for format in formats {
                popup.addItem(withTitle: format.displayName)
            }
            accessoryView.addSubview(popup)
            panel.accessoryView = accessoryView

            let picker = SpreadsheetFormatPicker(panel: panel, formats: formats)
            self.spreadsheetFormatPicker = picker
            popup.target = picker
            popup.action = #selector(SpreadsheetFormatPicker.formatChanged(_:))

            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                let format = SpreadsheetFormat(rawValue: url.pathExtension.lowercased()) ?? formats[0]

                DispatchQueue.global(qos: .userInitiated).async {
                    let data = SpreadsheetExporter.export(project, format: format)
                    do {
                        try data.write(to: url)
                    } catch {
                        print("Error exporting spreadsheet: \(error)")
                    }
                }
            }
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
        let subtotalEstimated = project.categories.filter { !$0.isProjectContingency }.reduce(0) { $0 + $1.totalEstimated }
        let subtotalActual = project.categories.filter { !$0.isProjectContingency }.reduce(0) { $0 + $1.totalActual }
        let subtotalRemaining = subtotalEstimated - subtotalActual

        for category in project.categories {
            if category.isProjectContingency { continue } // Skip contingency - show separately
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
        if let contingency = project.categories.first(where: { $0.isProjectContingency }) {
            let percentText = project.contingencyPercentage == floor(project.contingencyPercentage)
                ? String(format: "%.0f", project.contingencyPercentage)
                : String(format: "%.1f", project.contingencyPercentage)

            drawText(contingency.accountNumber, at: CGPoint(x: margin, y: y), fontSize: 10, in: context)
            drawText("\(contingency.name) (\(percentText)%)", at: CGPoint(x: margin + 60, y: y), fontSize: 10, in: context)
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
