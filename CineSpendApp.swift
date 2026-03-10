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
                
                Button("Save Project") {
                    projectManager.saveCurrentProject()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(projectManager.currentProject == nil)
            }
            
            CommandGroup(after: .importExport) {
                Button("Export PDF...") {
                    projectManager.exportToPDF()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(projectManager.currentProject == nil)
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
