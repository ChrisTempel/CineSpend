//
//  ContentView.swift
//  CineSpend
//
//  Main interface showing top sheet and details
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @State private var selectedCategoryID: UUID?
    @State private var refreshTrigger = UUID()
    
    var body: some View {
        Group {
            if let project = projectManager.currentProject {
                HSplitView {
                    // Left side: Top Sheet (50%)
                    TopSheetView(
                        project: Binding(
                            get: { project },
                            set: { projectManager.currentProject = $0 }
                        ),
                        selectedCategoryID: $selectedCategoryID,
                        updateTrigger: refreshTrigger
                    )
                    .frame(minWidth: 350, idealWidth: 450, maxWidth: .infinity)
                    
                    // Right side: Category Detail (50%)
                    ZStack {
                        // Always present, but hidden
                        CategoryDetailPlaceholder()
                            .opacity(selectedCategoryID == nil ? 1 : 0)
                        
                        // Actual detail view
                        if let selectedID = selectedCategoryID,
                           let categoryIndex = project.categories.firstIndex(where: { $0.id == selectedID }) {
                            CategoryDetailView(
                                category: Binding(
                                    get: { project.categories[categoryIndex] },
                                    set: { newValue in
                                        var updatedProject = project
                                        updatedProject.categories[categoryIndex] = newValue
                                        projectManager.currentProject = updatedProject
                                        // Force contingency recalculation without full refresh
                                        DispatchQueue.main.async {
                                            refreshTrigger = UUID()
                                        }
                                    }
                                ),
                                currency: project.currency
                            )
                            .transition(.opacity)
                        }
                    }
                    .frame(minWidth: 350, idealWidth: 450, maxWidth: .infinity)
                }
            } else {
                WelcomeView()
            }
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @EnvironmentObject var projectManager: ProjectManager
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "film")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Welcome to CineSpend")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Professional Film Budgeting for Independent Films")
                .font(.title3)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                Button(action: {
                    projectManager.createNewProject()
                }) {
                    Label("New Project", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button(action: {
                    projectManager.openProject()
                }) {
                    Label("Open Project", systemImage: "folder.fill")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Category Detail Placeholder
struct CategoryDetailPlaceholder: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Select a category from the Top Sheet")
                .foregroundColor(.secondary)
                .font(.title3)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

