//
//  ContentView.swift
//  CineSpend
//
//  Main interface showing top sheet and details
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @StateObject private var calculatorPresenter = CalculatorPresenter()
    @State private var refreshTrigger = UUID()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Group {
                    if let project = projectManager.currentProject {
                        HSplitView {
                            // Left side: Top Sheet (50%)
                            TopSheetView(
                                project: Binding(
                                    get: { project },
                                    set: { projectManager.currentProject = $0 }
                                ),
                                selectedCategoryID: $projectManager.selectedCategoryID,
                                updateTrigger: refreshTrigger
                            )
                            .frame(minWidth: 350, idealWidth: 450, maxWidth: .infinity)

                            // Right side: Category Detail (50%)
                            ZStack {
                                // Always present, but hidden
                                CategoryDetailPlaceholder()
                                    .opacity(projectManager.selectedCategoryID == nil ? 1 : 0)

                                // Actual detail view
                                if let selectedID = projectManager.selectedCategoryID,
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
                .environmentObject(calculatorPresenter)
                // Blurring the actual content (rather than trying to blur "through" a
                // translucent Material sibling, which samples unreliably against other
                // SwiftUI views in the same ZStack) is what makes the app visible-but-soft
                // behind the card, instead of the backdrop rendering as flat white.
                .blur(radius: calculatorPresenter.active != nil ? 1 : 0)
                .disabled(calculatorPresenter.active != nil)

                // Window-spanning Unit Calculator overlay - see CalculatorPresenter for why
                // this isn't a native .sheet().
                if let request = calculatorPresenter.active {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                        .onTapGesture { calculatorPresenter.dismiss() }

                    UnitCalculatorView(
                        // Built fresh here, reading/writing projectManager.currentProject
                        // directly (not a captured project/category snapshot), so Done can
                        // never overwrite the model with a stale copy - see CalculatorPresenter.
                        lineItem: Binding<LineItem>(
                            get: {
                                projectManager.currentProject?
                                    .categories.first(where: { $0.id == request.categoryID })?
                                    .lineItems.first(where: { $0.id == request.lineItemID })
                                ?? LineItem(description: "", estimated: 0, actual: 0)
                            },
                            set: { newValue in
                                guard var project = projectManager.currentProject,
                                      let categoryIndex = project.categories.firstIndex(where: { $0.id == request.categoryID }),
                                      let lineItemIndex = project.categories[categoryIndex].lineItems.firstIndex(where: { $0.id == request.lineItemID })
                                else { return }
                                project.categories[categoryIndex].lineItems[lineItemIndex] = newValue
                                projectManager.currentProject = project
                            }
                        ),
                        currency: request.currency,
                        mode: request.mode,
                        maxSize: geometry.size,
                        onDismiss: { calculatorPresenter.dismiss() }
                    )
                }
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

