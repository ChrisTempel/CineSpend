//
//  Models.swift
//  CineSpend
//
//  Data models for film budgeting
//

import Foundation

// MARK: - Currency
enum Currency: String, Codable, CaseIterable {
    case usd = "USD"
    case gbp = "GBP"
    case eur = "EUR"
    case cad = "CAD"
    case aud = "AUD"
    case nzd = "NZD"
    case inr = "INR"
    case krw = "KRW"
    case jpy = "JPY"
    case mxn = "MXN"
    
    var symbol: String {
        switch self {
        case .usd, .cad, .aud, .nzd, .mxn: return "$"
        case .gbp: return "£"
        case .eur: return "€"
        case .inr: return "₹"
        case .krw: return "₩"
        case .jpy: return "¥"
        }
    }
    
    var displayName: String {
        switch self {
        case .usd: return "$ USD - US Dollar"
        case .gbp: return "£ GBP - British Pound"
        case .eur: return "€ EUR - Euro"
        case .cad: return "$ CAD - Canadian Dollar"
        case .aud: return "$ AUD - Australian Dollar"
        case .nzd: return "$ NZD - New Zealand Dollar"
        case .inr: return "₹ INR - Indian Rupee"
        case .krw: return "₩ KRW - South Korean Won"
        case .jpy: return "¥ JPY - Japanese Yen"
        case .mxn: return "$ MXN - Mexican Peso"
        }
    }
    
    var code: String {
        rawValue
    }
}

// MARK: - Project
struct Project: Codable, Identifiable {
    var id = UUID()
    var name: String
    var currency: Currency = .usd
    var preparedBy: String = ""
    var contingencyPercentage: Double = 10.0
    var dateCreated: Date
    var dateModified: Date
    var categories: [BudgetCategory]
    
    init(name: String, currency: Currency = .usd) {
        self.name = name
        self.currency = currency
        self.preparedBy = ""
        self.contingencyPercentage = 10.0
        self.dateCreated = Date()
        self.dateModified = Date()
        self.categories = BudgetCategory.defaultCategories()
    }
    
    var totalEstimated: Double {
        categories.reduce(0) { $0 + $1.totalEstimated }
    }
    
    var totalActual: Double {
        categories.reduce(0) { $0 + $1.totalActual }
    }
    
    var totalRemaining: Double {
        totalEstimated - totalActual
    }
    
    mutating func updateModifiedDate() {
        dateModified = Date()
    }
}

// MARK: - Budget Category
struct BudgetCategory: Codable, Identifiable {
    var id = UUID()
    var accountNumber: String
    var name: String
    var lineItems: [LineItem]

    // Marks the one category that holds the whole-project contingency (see
    // Project.contingencyPercentage). Its accountNumber and name are ordinary,
    // freely editable fields like any other category's - this flag, not the
    // account number, is what the app actually uses to find it.
    var isProjectContingency: Bool = false

    // An internal contingency scoped to this category alone (e.g. a VFX account
    // that wants its own buffer on top of its line items). nil = disabled. Adds
    // directly to this category's own totalEstimated; unlike a normal line item,
    // it isn't itemized and doesn't affect totalActual.
    var contingencyPercentage: Double? = nil

    // Custom decoding so isProjectContingency (added after this format shipped) is
    // treated as false when absent, instead of failing to decode every file that
    // predates it - unlike most fields in this app's model, this one is meant to be
    // forward-compatible with files that don't have it yet.
    enum CodingKeys: String, CodingKey {
        case id, accountNumber, name, lineItems, isProjectContingency, contingencyPercentage
    }

    init(id: UUID = UUID(), accountNumber: String, name: String, lineItems: [LineItem],
         isProjectContingency: Bool = false, contingencyPercentage: Double? = nil) {
        self.id = id
        self.accountNumber = accountNumber
        self.name = name
        self.lineItems = lineItems
        self.isProjectContingency = isProjectContingency
        self.contingencyPercentage = contingencyPercentage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        accountNumber = try container.decode(String.self, forKey: .accountNumber)
        name = try container.decode(String.self, forKey: .name)
        lineItems = try container.decode([LineItem].self, forKey: .lineItems)
        isProjectContingency = try container.decodeIfPresent(Bool.self, forKey: .isProjectContingency) ?? false
        contingencyPercentage = try container.decodeIfPresent(Double.self, forKey: .contingencyPercentage)
    }

    var lineItemsSubtotalEstimated: Double {
        lineItems.reduce(0) { $0 + $1.estimated }
    }

    var contingencyEstimated: Double {
        guard let contingencyPercentage else { return 0 }
        return lineItemsSubtotalEstimated * (contingencyPercentage / 100)
    }

    var totalEstimated: Double {
        lineItemsSubtotalEstimated + contingencyEstimated
    }

    var totalActual: Double {
        lineItems.reduce(0) { $0 + $1.actual }
    }

    var totalRemaining: Double {
        totalEstimated - totalActual
    }

    // Default indie film budget categories
    static func defaultCategories() -> [BudgetCategory] {
        return [
            BudgetCategory(accountNumber: "1000", name: "Story & Rights", lineItems: [
                LineItem(description: "Story Rights Purchase", estimated: 0, actual: 0),
                LineItem(description: "Screenplay", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "2000", name: "Producers Unit", lineItems: [
                LineItem(description: "Executive Producer", estimated: 0, actual: 0),
                LineItem(description: "Producer", estimated: 0, actual: 0),
                LineItem(description: "Line Producer", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "3000", name: "Direction", lineItems: [
                LineItem(description: "Director", estimated: 0, actual: 0),
                LineItem(description: "Assistant Director", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "4000", name: "Cast", lineItems: [
                LineItem(description: "Lead Actors", estimated: 0, actual: 0),
                LineItem(description: "Supporting Actors", estimated: 0, actual: 0),
                LineItem(description: "Day Players", estimated: 0, actual: 0),
                LineItem(description: "Extras/Background", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "5000", name: "Production Staff", lineItems: [
                LineItem(description: "Production Manager", estimated: 0, actual: 0),
                LineItem(description: "Production Coordinator", estimated: 0, actual: 0),
                LineItem(description: "Production Assistants", estimated: 0, actual: 0),
                LineItem(description: "Script Supervisor", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "6000", name: "Camera", lineItems: [
                LineItem(description: "Director of Photography", estimated: 0, actual: 0),
                LineItem(description: "Camera Operator", estimated: 0, actual: 0),
                LineItem(description: "1st AC", estimated: 0, actual: 0),
                LineItem(description: "2nd AC", estimated: 0, actual: 0),
                LineItem(description: "Camera Package Rental", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "7000", name: "Sound", lineItems: [
                LineItem(description: "Sound Mixer", estimated: 0, actual: 0),
                LineItem(description: "Boom Operator", estimated: 0, actual: 0),
                LineItem(description: "Sound Equipment Rental", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "8000", name: "Grip & Electric", lineItems: [
                LineItem(description: "Gaffer", estimated: 0, actual: 0),
                LineItem(description: "Key Grip", estimated: 0, actual: 0),
                LineItem(description: "Best Boy Electric", estimated: 0, actual: 0),
                LineItem(description: "Best Boy Grip", estimated: 0, actual: 0),
                LineItem(description: "Lighting & Grip Rental", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "9000", name: "Art Department", lineItems: [
                LineItem(description: "Production Designer", estimated: 0, actual: 0),
                LineItem(description: "Art Director", estimated: 0, actual: 0),
                LineItem(description: "Set Decorator", estimated: 0, actual: 0),
                LineItem(description: "Props Master", estimated: 0, actual: 0),
                LineItem(description: "Set Dressing & Props", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "10000", name: "Wardrobe", lineItems: [
                LineItem(description: "Costume Designer", estimated: 0, actual: 0),
                LineItem(description: "Wardrobe Supervisor", estimated: 0, actual: 0),
                LineItem(description: "Costume Purchases & Rentals", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "11000", name: "Makeup & Hair", lineItems: [
                LineItem(description: "Key Makeup Artist", estimated: 0, actual: 0),
                LineItem(description: "Key Hair Stylist", estimated: 0, actual: 0),
                LineItem(description: "Makeup & Hair Supplies", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "12000", name: "Transportation", lineItems: [
                LineItem(description: "Transportation Coordinator", estimated: 0, actual: 0),
                LineItem(description: "Picture Vehicle Rentals", estimated: 0, actual: 0),
                LineItem(description: "Production Vehicle Rentals", estimated: 0, actual: 0),
                LineItem(description: "Fuel", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "13000", name: "Locations", lineItems: [
                LineItem(description: "Location Manager", estimated: 0, actual: 0),
                LineItem(description: "Location Fees", estimated: 0, actual: 0),
                LineItem(description: "Location Permits", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "14000", name: "Production Film & Lab", lineItems: [
                LineItem(description: "Digital Storage", estimated: 0, actual: 0),
                LineItem(description: "Data Management", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "15000", name: "Post-Production", lineItems: [
                LineItem(description: "Editor", estimated: 0, actual: 0),
                LineItem(description: "Assistant Editor", estimated: 0, actual: 0),
                LineItem(description: "Editing System Rental", estimated: 0, actual: 0),
                LineItem(description: "Color Grading", estimated: 0, actual: 0),
                LineItem(description: "Sound Design", estimated: 0, actual: 0),
                LineItem(description: "Sound Mix", estimated: 0, actual: 0),
                LineItem(description: "Music Composer", estimated: 0, actual: 0),
                LineItem(description: "Music Licensing", estimated: 0, actual: 0),
                LineItem(description: "Visual Effects", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "16000", name: "Insurance & Legal", lineItems: [
                LineItem(description: "Production Insurance", estimated: 0, actual: 0),
                LineItem(description: "Legal Fees", estimated: 0, actual: 0),
                LineItem(description: "Clearance Fees", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "17000", name: "Publicity", lineItems: [
                LineItem(description: "Unit Publicist", estimated: 0, actual: 0),
                LineItem(description: "Still Photographer", estimated: 0, actual: 0),
                LineItem(description: "EPK/BTS Videographer", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "18000", name: "General Expenses", lineItems: [
                LineItem(description: "Office Rental", estimated: 0, actual: 0),
                LineItem(description: "Office Supplies", estimated: 0, actual: 0),
                LineItem(description: "Phone & Internet", estimated: 0, actual: 0),
                LineItem(description: "Catering", estimated: 0, actual: 0),
                LineItem(description: "Craft Services", estimated: 0, actual: 0)
            ]),
            BudgetCategory(accountNumber: "19000", name: "Contingency", lineItems: [
                LineItem(description: "Contingency (10%)", estimated: 0, actual: 0)
            ], isProjectContingency: true)
        ]
    }
}

// MARK: - Line Item
struct LineItem: Codable, Identifiable {
    var id = UUID()
    var description: String
    var estimated: Double
    var actual: Double
    var notes: String = ""
    var units: [UnitBreakdown] = []
    // Whether this line item's unit breakdown preview is collapsed in Category
    // Detail. Opt-out: false (shown) by default, and saved with the file.
    var breakdownCollapsed: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, description, estimated, actual, notes, units, breakdownCollapsed
    }
    
    var remaining: Double {
        estimated - actual
    }
    
    // Calculate estimated from units if units exist
    var calculatedEstimated: Double {
        units.reduce(0) { $0 + ($1.amount * $1.units * $1.rate) }
    }
    
    // Calculate actual from units if units exist
    var calculatedActual: Double {
        units.reduce(0) { $0 + ($1.amount * $1.units * $1.actualRate) }
    }
}

// Custom decoding lives in an extension so LineItem keeps its memberwise
// initializer. breakdownCollapsed was added after the format shipped, so it's
// treated as false (expanded) when absent; every other field decodes as before.
extension LineItem {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        description = try container.decode(String.self, forKey: .description)
        estimated = try container.decode(Double.self, forKey: .estimated)
        actual = try container.decode(Double.self, forKey: .actual)
        notes = try container.decode(String.self, forKey: .notes)
        units = try container.decode([UnitBreakdown].self, forKey: .units)
        breakdownCollapsed = try container.decodeIfPresent(Bool.self, forKey: .breakdownCollapsed) ?? false
    }
}

// MARK: - Unit Breakdown
struct UnitBreakdown: Codable, Identifiable {
    var id = UUID()
    var description: String
    var amount: Double
    var units: Double
    var rate: Double
    var actualRate: Double
    
    var estimatedSubtotal: Double {
        amount * units * rate
    }
    
    var actualSubtotal: Double {
        amount * units * actualRate
    }
}
