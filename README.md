# CineSpend - Professional Film Budget Management for macOS

A powerful, user-friendly film budgeting application built with Swift and SwiftUI for macOS. Designed as an affordable alternative to Movie Magic Budgeting for independent filmmakers and production companies.

![macOS](https://img.shields.io/badge/macOS-12.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.5+-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0+-green)

## Features

### Core Budgeting
-  **Three-Level Budget Hierarchy** - Top Sheet → Categories → Unit Breakdowns (just like Movie Magic)
-  **Unit Calculator** - Click any estimated/actual value to open a detailed calculator
  - Enter Amt × Units × Rate for precise calculations
  - Separate calculators for Estimated and Actual costs
-  **Automatic Contingency** - Always calculates 10% of subtotal automatically
-  **19 Industry-Standard Categories** - Pre-loaded with indie film budget structure
-  **Duplicate Line Items** - Right-click any line item to duplicate (copies all values and units)
-  **Category Percentages** - See what % of budget each category represents
-  **Notes Support** - Add detailed notes to any line item

### Professional Output
-  **PDF Export** - Generate professional budget PDFs with:
  - Complete top sheet with all categories
  - Detail pages for each category
  - Subtotal, Contingency (10%), and Grand Total
  - "Prepared By" field for your name
  - Professional formatting ready for investors/producers
-  **Project Save/Load** - Save budgets as `.cinespend` files
-  **Auto-Save Modified Date** - Tracks last modification time

### User Experience
-  **Dark/Light Mode** - Full appearance customization
-  **Split View Interface** - Category list on left, details on right
-  **Keyboard Shortcuts** - Fast workflow with ⌘N, ⌘S, ⌘O, ⌘⇧E
-  **Clean, Modern UI** - Native macOS design with SwiftUI

## Installation

### Requirements
- macOS Monterey (12.0) or later
- Xcode 14.0 or later (for building from source)

### Building from Source

1. **Clone or Download** this repository

2. **Open Xcode**
   - Launch Xcode on your Mac

3. **Create New Project**
   - File → New → Project
   - Select "macOS" → "App"
   - Product Name: `CineSpend`
   - Interface: `SwiftUI`
   - Language: `Swift`

4. **Add Source Files**
   - Delete the default `CineSpendApp.swift` and `ContentView.swift`
   - Drag all `.swift` files from the `CineSpend` folder into your project
   - Make sure "Copy items if needed" is checked

5. **Add Entitlements**
   - Drag `CineSpend.entitlements` into your project
   - In Project Settings → Signing & Capabilities → Enable:
     - User Selected File (Read/Write)
     - Downloads Folder (Read/Write)

6. **Build and Run**
   - Press ⌘R or click the Play button
   - CineSpend will launch!

## How to Use

### Getting Started

#### Create a New Budget
1. Launch CineSpend
2. Click **"New Project"** or press **⌘N**
3. Click the project name at the top to rename it
4. Enter your name in the **"Prepared by"** field (top right)

#### Navigate the Interface
- **Left Side** - Top Sheet showing all budget categories
- **Right Side** - Detailed view of selected category with line items
- Click any category to see its details

### Working with Line Items

#### Adding Line Items
1. Select a category from the Top Sheet
2. Click **"+ Add Line Item"** in the detail view
3. Name your line item

#### Using the Unit Calculator
1. Click the **blue underlined** estimated or actual amount
2. Calculator opens with a table for unit breakdowns
3. Click **"+ Add Unit"** to add rows
4. Enter:
   - **Description** - What you're budgeting (e.g., "Camera Body")
   - **Amt** - Quantity (e.g., 1)
   - **Units** - Days, weeks, etc. (e.g., 10 days)
   - **Rate** - Cost per unit (e.g., $500/day)
5. See live **Subtotal** calculation (1 × 10 × $500 = $5,000)
6. Add multiple units for complex breakdowns
7. Click **"Done"** to save

**Example:**
```
Camera Package Rental
├─ Camera Body:    1 × 10 days × $500  = $5,000
├─ Lenses Set:     1 × 10 days × $300  = $3,000
└─ Accessories:    1 × 10 days × $100  = $1,000
                                 Total: $9,000
```

#### Duplicate Line Items
1. Click the **"..."** menu on any line item
2. Select **"Duplicate"**
3. Edit the copy as needed (great for similar crew positions)

#### Add Notes
1. Click the **"..."** menu on any line item
2. Select **"Add Notes"**
3. Type notes (vendor info, payment terms, etc.)

### Understanding the Budget Structure

```
1000 - Story & Rights          $10,000    2.0%
2000 - Producers Unit          $20,000    4.0%
...
18000 - General Expenses       $5,000     1.0%
───────────────────────────────────────────────
SUBTOTAL                       $500,000   100.0%
19000 - Contingency (10%)      $50,000
───────────────────────────────────────────────
TOTAL                          $550,000
```

**Key Concepts:**
- **Subtotal** = All categories (1000-18000)
- **Contingency** = Automatically 10% of subtotal
- **Total** = Subtotal + Contingency
- **%** = Percentage of subtotal (shown for each category)

### Saving Your Work

#### Save Project
- **First Save**: ⌘S → Choose location and name
- **Subsequent Saves**: ⌘S → Overwrites existing file
- Files save as `.cinespend` format

#### Open Existing Project
- Press **⌘O** or File → Open Project
- Select a `.cinespend` file

### Exporting to PDF

1. Press **⌘⇧E** or File → Export PDF
2. Choose save location
3. PDF includes:
   - Top Sheet with all categories
   - Subtotal, Contingency (10%), and Grand Total
   - Category percentages
   - "Prepared By" field with your name
   - Detailed breakdown pages for each category

Perfect for sending to:
- Investors
- Producers
- Studio executives
- Finance partners
- Production accountants

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **⌘N** | New Project |
| **⌘O** | Open Project |
| **⌘S** | Save Project |
| **⌘⇧E** | Export PDF |
| **⌘⌥L** | Light Mode |
| **⌘⌥D** | Dark Mode |
| **⌘⌥S** | System Appearance |

## Budget Categories

CineSpend comes pre-loaded with 19 industry-standard budget categories:

1. **1000 - Story & Rights** - Scripts, story rights
2. **2000 - Producers Unit** - Producers, line producers
3. **3000 - Direction** - Director, ADs
4. **4000 - Cast** - Actors, extras
5. **5000 - Production Staff** - PAs, coordinators
6. **6000 - Camera** - DP, operators, rentals
7. **7000 - Sound** - Mixer, boom op, equipment
8. **8000 - Grip & Electric** - Gaffer, key grip, lighting
9. **9000 - Art Department** - Production designer, props
10. **10000 - Wardrobe** - Costumes, purchases
11. **11000 - Makeup & Hair** - Key makeup, hair stylist
12. **12000 - Transportation** - Vehicles, fuel
13. **13000 - Locations** - Location fees, permits
14. **14000 - Production Film & Lab** - Digital storage, data management
15. **15000 - Post-Production** - Editing, color, sound, VFX, music
16. **16000 - Insurance & Legal** - Production insurance, legal fees
17. **17000 - Publicity** - Publicist, photographer, EPK
18. **18000 - General Expenses** - Office, catering, craft services
19. **19000 - Contingency** - Auto-calculated at 10% of subtotal

Each category includes common line items that you can edit, delete, or expand.

## Tips for Independent Filmmakers

### Budget Best Practices

1. **Start with Estimates**
   - Fill in estimated costs first
   - Be realistic - use real vendor quotes when possible
   - Don't forget fringe benefits and taxes

2. **Use Unit Breakdowns**
   - Break down complex costs (crew × days × rate)
   - Easier to adjust if schedule changes
   - More transparent for investors

3. **Track Actuals During Production**
   - Update actual costs as you spend
   - Watch your remaining budget (green = good, red = over)
   - Adjust future spending based on actuals

4. **Leverage Contingency**
   - 10% contingency is industry standard
   - Use it for unexpected costs
   - Don't budget it away - it's your safety net

5. **Export PDFs Regularly**
   - Before pitching to investors
   - Before major production decisions
   - When applying for grants/funding
   - After wrapping each production phase

### Common Workflows

**Pre-Production:**
1. Create new budget
2. Fill in estimated costs with unit breakdowns
3. Export PDF for investors/partners
4. Get approvals and make adjustments
5. Save as "FilmName_PreProd_v1.cinespend"

**During Production:**
1. Open your saved budget
2. Update actual costs daily/weekly
3. Monitor remaining budget
4. Export updated PDFs for weekly production meetings

**Post-Production:**
1. Continue tracking post costs
2. Compare final actuals vs. estimates
3. Export final budget for records
4. Learn from variances for next project

## Troubleshooting

### App won't build
- Ensure all `.swift` files are in the project target
- Check macOS deployment target is 12.0+
- Clean build folder (⌘⇧K) and rebuild

### PDF export not working
- Grant file access permissions in System Preferences
- Check write permissions to destination folder
- Try exporting to Downloads folder

### Changes not saving
- Use ⌘S to save manually
- Check file permissions at save location
- Verify you have disk space available

### Calculator values not updating
- Make sure to press Tab or Enter after typing values
- Click "Done" to apply calculations
- Check that you're editing the right mode (Estimated vs Actual)

## File Format

CineSpend saves projects as JSON files with `.cinespend` extension:

```json
{
  "name": "My Film Budget",
  "preparedBy": "Jane Smith",
  "dateCreated": "2026-03-06T12:00:00Z",
  "dateModified": "2026-03-06T15:30:00Z",
  "categories": [...]
}
```

Files are:
- Human-readable (JSON format)
- Version-control friendly
- Cross-platform compatible
- Easy to backup and share

## Why CineSpend?

### vs. Movie Magic Budgeting

| Feature | CineSpend | Movie Magic |
|---------|-----------|-------------|
| **Price** | Free | $500-1000+ |
| **Platform** | macOS | Windows/Mac |
| **Learning Curve** | Gentle | Steep |
| **Unit Breakdowns** | ✅ Built-in | ✅ |
| **PDF Export** | ✅ Free | ✅ |
| **Auto Contingency** | ✅ | Manual |
| **Modern UI** | ✅ SwiftUI | Legacy |
| **Updates** | Open source | Subscription |

### Perfect For:
- Independent filmmakers
- Film students
- Short film productions
- Documentary producers
- Music video budgeters
- Anyone learning film budgeting
- Productions under $5M

## Roadmap

Potential future features (community feedback welcome):

- [ ] Import from CSV/Excel
- [ ] Budget templates (Documentary, Narrative, Commercial, Music Video)
- [ ] Multi-currency support
- [ ] Fringes and payroll tax calculations
- [ ] Above-the-line vs. below-the-line breakdowns
- [ ] Budget comparison tools
- [ ] Cloud sync
- [ ] iOS companion app
- [ ] Collaboration features

## Contributing

This is an independent open-source project. Contributions, suggestions, and feedback are welcome!

## License

GPL-3.0 License - Free for personal and commercial use

## Credits

Built with ❤️ for the independent film community.

**Technologies:**
- Swift
- SwiftUI
- AppKit (for PDF generation)
- Core Graphics

---

**CineSpend** - Professional budgeting for independent filmmakers, without the enterprise price tag.

*Made by filmmakers, for filmmakers.* 🎬
