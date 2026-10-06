//
//  CineSpendApp.swift
//  CineSpend
//
//  A film budgeting application for macOS
//

import SwiftUI

@main
struct CineSpendApp: App {
    @StateObject private var projectManager = ProjectManager()
    @AppStorage("colorScheme") private var colorScheme: ColorSchemeOption = .system
    
    enum ColorSchemeOption: String {
        case light, dark, system
        
        var displayName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .system: return "System"
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectManager)
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(colorScheme == .system ? nil : (colorScheme == .dark ? .dark : .light))
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    projectManager.createNewProject()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open Project...") {
                    projectManager.openProject()
                }
                .keyboardShortcut("o", modifiers: .command)

                Menu("Open Recent") {
                    ForEach(projectManager.recentFileURLs, id: \.self) { url in
                        Button(url.deletingPathExtension().lastPathComponent) {
                            projectManager.loadProject(from: url)
                        }
                    }
                    if !projectManager.recentFileURLs.isEmpty {
                        Divider()
                        Button("Clear Menu") {
                            projectManager.clearRecentFiles()
                        }
                    }
                }
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save Project") {
                    projectManager.saveCurrentProject()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(projectManager.currentProject == nil)

                Button("Save Project As...") {
                    projectManager.saveCurrentProjectAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(projectManager.currentProject == nil)

                Divider()

                Button("Revert to Saved") {
                    projectManager.revertToSaved()
                }
                .disabled(projectManager.currentFileURL == nil)
            }

            CommandGroup(after: .importExport) {
                Button("Export Spreadsheet...") {
                    projectManager.exportToSpreadsheet()
                }
                .keyboardShortcut("e", modifiers: [.command, .option])
                .disabled(projectManager.currentProject == nil)

                Button("Export PDF...") {
                    projectManager.exportToPDF()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(projectManager.currentProject == nil)
            }
            
            CommandMenu("Category") {
                Toggle("Enable Category Contingency", isOn: Binding(
                    get: { projectManager.selectedCategory?.contingencyPercentage != nil },
                    set: { enabled in
                        guard let id = projectManager.selectedCategoryID else { return }
                        projectManager.setCategoryContingency(categoryID: id, enabled: enabled)
                    }
                ))
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(projectManager.selectedCategory == nil)
            }

            CommandMenu("Appearance") {
                Button("Light Mode") {
                    colorScheme = .light
                }
                .keyboardShortcut("l", modifiers: [.command, .option])
                
                Button("Dark Mode") {
                    colorScheme = .dark
                }
                .keyboardShortcut("d", modifiers: [.command, .option])
                
                Button("System Default") {
                    colorScheme = .system
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                
                Divider()
                
                Text("Current: \(colorScheme.displayName)")
                    .foregroundColor(.secondary)
            }
        }
    }
}
