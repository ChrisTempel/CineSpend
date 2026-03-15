# Changelog

All notable changes to CineSpend will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-10

### Initial Release

#### Added
- Three-level budget hierarchy (Top Sheet → Categories → Unit Breakdowns)
- Unit calculator for detailed cost breakdowns (Amt × Units × Rate)
- Separate calculators for Estimated and Actual costs
- 19 industry-standard budget categories pre-loaded
- Automatic contingency calculation with editable percentage
- Category percentage view showing % of total budget
- Duplicate line item functionality
- Notes support for line items
- PDF export with professional formatting
- "Prepared By" field for budget attribution
- Project save/load as `.cinespend` files
- Dark/Light mode support with system default option
- Split view interface with stable divider
- Keyboard shortcuts (⌘N, ⌘S, ⌘O, ⌘⇧E, ⌘⌥L, ⌘⌥D)
- Modern macOS UI with SwiftUI

#### Features
- **Top Sheet**: Overview of all categories with totals, subtotal, and contingency
- **Category Detail**: Detailed view of line items within each category
- **Unit Calculator**: Click any estimated/actual value to break down costs
- **Auto-Contingency**: Automatically calculates based on editable percentage (default 10%)
- **PDF Export**: Professional budgets ready for investors and producers
- **Budget Structure**: Proper Subtotal → Contingency → Total hierarchy

#### Budget Categories
1. Story & Rights
2. Producers Unit
3. Direction
4. Cast
5. Production Staff
6. Camera
7. Sound
8. Grip & Electric
9. Art Department
10. Wardrobe
11. Makeup & Hair
12. Transportation
13. Locations
14. Production Film & Lab
15. Post-Production
16. Insurance & Legal
17. Publicity
18. General Expenses
19. Contingency (auto-calculated)

### Technical Details
- Built with Swift 5.5+ and SwiftUI 3.0+
- Requires macOS 12.0 (Monterey) or later
- Native macOS app with App Sandbox enabled
- JSON-based project file format for easy backup and version control

---

## [Unreleased]

### Planned Features
- CSV/Excel import/export
- Budget templates (Documentary, Narrative, Commercial, Music Video)
- Multi-currency support
- Fringes and payroll tax calculations
- Above-the-line vs. below-the-line breakdowns
- Budget comparison tools
- Cloud sync
- iOS companion app
- Collaboration features

---

[1.0.0]: https://github.com/yourusername/CineSpend/releases/tag/v1.0.0
