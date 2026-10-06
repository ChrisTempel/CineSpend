//
//  SpreadsheetExporter.swift
//  CineSpend
//
//  Flattens a Project into tabular rows and serializes them to CSV, XLSX, or JSON.
//

import Foundation

enum SpreadsheetFormat: String, CaseIterable {
    case csv
    case xlsx
    case json

    var fileExtension: String { rawValue }

    var displayName: String {
        switch self {
        case .csv: return "CSV"
        case .xlsx: return "Excel Workbook"
        case .json: return "JSON"
        }
    }
}

enum SpreadsheetExporter {

    // MARK: - Row model shared by all three formats

    private enum RowKind: String {
        case lineItem
        case categoryTotal
        case subtotal
        case total
    }

    private struct Row {
        let account: String
        let category: String
        let description: String
        let estimated: Double
        let actual: Double
        let remaining: Double
        let notes: String
        let kind: RowKind
    }

    private static func buildRows(for project: Project) -> [Row] {
        var rows: [Row] = []

        for category in project.categories {
            for item in category.lineItems {
                rows.append(Row(
                    account: category.accountNumber,
                    category: category.name,
                    description: item.description,
                    estimated: item.estimated,
                    actual: item.actual,
                    remaining: item.remaining,
                    notes: item.notes,
                    kind: .lineItem
                ))
            }
            rows.append(Row(
                account: category.accountNumber,
                category: category.name,
                description: "\(category.name) Total",
                estimated: category.totalEstimated,
                actual: category.totalActual,
                remaining: category.totalRemaining,
                notes: "",
                kind: .categoryTotal
            ))
        }

        // Mirrors the PDF top sheet: subtotal excludes the project contingency, total includes it.
        let subtotalEstimated = project.categories
            .filter { !$0.isProjectContingency }
            .reduce(0) { $0 + $1.totalEstimated }
        let subtotalActual = project.categories
            .filter { !$0.isProjectContingency }
            .reduce(0) { $0 + $1.totalActual }

        rows.append(Row(account: "", category: "", description: "SUBTOTAL",
                         estimated: subtotalEstimated, actual: subtotalActual,
                         remaining: subtotalEstimated - subtotalActual, notes: "", kind: .subtotal))
        rows.append(Row(account: "", category: "", description: "TOTAL",
                         estimated: project.totalEstimated, actual: project.totalActual,
                         remaining: project.totalRemaining, notes: "", kind: .total))

        return rows
    }

    // MARK: - Public entry point

    static func export(_ project: Project, format: SpreadsheetFormat) -> Data {
        let rows = buildRows(for: project)
        switch format {
        case .csv: return makeCSV(project: project, rows: rows)
        case .xlsx: return makeXLSX(project: project, rows: rows)
        case .json: return makeJSON(project: project, rows: rows)
        }
    }

    // MARK: - Number formatting

    // Always uses '.' as the decimal separator, regardless of the system locale -
    // required for XLSX's <v> cells and safest for CSVs opened on other machines.
    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    private static func decimalString(_ value: Double) -> String {
        String(format: "%.2f", locale: posixLocale, value)
    }

    // MARK: - CSV

    private static func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func makeCSV(project: Project, rows: [Row]) -> Data {
        var lines: [String] = []
        lines.append(["Account", "Category", "Description", "Estimated", "Actual", "Remaining", "Notes"]
            .map(csvField).joined(separator: ","))

        for row in rows {
            let fields = [
                row.account,
                row.category,
                row.description,
                decimalString(row.estimated),
                decimalString(row.actual),
                decimalString(row.remaining),
                row.notes,
            ]
            lines.append(fields.map(csvField).joined(separator: ","))
        }

        let csvString = lines.joined(separator: "\r\n") + "\r\n"
        // UTF-8 BOM so Excel (especially on Windows) reliably detects the encoding.
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(csvString.data(using: .utf8) ?? Data())
        return data
    }

    // MARK: - JSON

    private struct ExportRow: Encodable {
        let accountNumber: String
        let category: String
        let description: String
        let estimated: Double
        let actual: Double
        let remaining: Double
        let notes: String
        let rowType: String
    }

    private struct ExportDocument: Encodable {
        let projectName: String
        let currency: String
        let preparedBy: String
        let contingencyPercentage: Double
        let dateCreated: Date
        let dateModified: Date
        let rows: [ExportRow]
    }

    private static func makeJSON(project: Project, rows: [Row]) -> Data {
        let document = ExportDocument(
            projectName: project.name,
            currency: project.currency.code,
            preparedBy: project.preparedBy,
            contingencyPercentage: project.contingencyPercentage,
            dateCreated: project.dateCreated,
            dateModified: project.dateModified,
            rows: rows.map {
                ExportRow(
                    accountNumber: $0.account,
                    category: $0.category,
                    description: $0.description,
                    estimated: $0.estimated,
                    actual: $0.actual,
                    remaining: $0.remaining,
                    notes: $0.notes,
                    rowType: $0.kind.rawValue
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(document)) ?? Data()
    }

    // MARK: - XLSX

    private static func xmlEscape(_ value: String) -> String {
        var result = value.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\r\n", with: " ")
        result = result.replacingOccurrences(of: "\n", with: " ")
        return result
    }

    private static let columnLetters = ["A", "B", "C", "D", "E", "F", "G"]

    private static func makeXLSX(project: Project, rows: [Row]) -> Data {
        let currencySymbol = xmlEscape(project.currency.symbol)
        let sheetXML = worksheetXML(rows: rows, currencySymbol: currencySymbol)
        let stylesXML = self.stylesXML(currencySymbol: currencySymbol)

        let entries: [ZipEntry] = [
            ZipEntry(name: "[Content_Types].xml", data: Data(contentTypesXML.utf8)),
            ZipEntry(name: "_rels/.rels", data: Data(rootRelsXML.utf8)),
            ZipEntry(name: "xl/workbook.xml", data: Data(workbookXML.utf8)),
            ZipEntry(name: "xl/_rels/workbook.xml.rels", data: Data(workbookRelsXML.utf8)),
            ZipEntry(name: "xl/styles.xml", data: Data(stylesXML.utf8)),
            ZipEntry(name: "xl/worksheets/sheet1.xml", data: Data(sheetXML.utf8)),
        ]
        return makeZip(entries: entries)
    }

    private static let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>
    """

    private static let rootRelsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
    """

    private static let workbookXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Budget" sheetId="1" r:id="rId1"/></sheets></workbook>
    """

    private static let workbookRelsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>
    """

    private static func stylesXML(currencySymbol: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="1"><numFmt numFmtId="164" formatCode="&quot;\(currencySymbol)&quot;#,##0.00"/></numFmts><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="4"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/><xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="164" fontId="1" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/></cellXfs></styleSheet>
        """
    }

    private static func worksheetXML(rows: [Row], currencySymbol: String) -> String {
        let headers = ["Account", "Category", "Description", "Estimated", "Actual", "Remaining", "Notes"]
        var xml = ""
        xml += "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">"
        xml += "<dimension ref=\"A1:G\(rows.count + 1)\"/>"
        xml += "<cols><col min=\"1\" max=\"1\" width=\"10\" customWidth=\"1\"/><col min=\"2\" max=\"2\" width=\"24\" customWidth=\"1\"/><col min=\"3\" max=\"3\" width=\"38\" customWidth=\"1\"/><col min=\"4\" max=\"6\" width=\"14\" customWidth=\"1\"/><col min=\"7\" max=\"7\" width=\"40\" customWidth=\"1\"/></cols>"
        xml += "<sheetData>"

        func textCell(_ column: String, _ value: String, bold: Bool) -> String {
            "<c r=\"\(column)\" t=\"inlineStr\" s=\"\(bold ? 1 : 0)\"><is><t>\(xmlEscape(value))</t></is></c>"
        }
        func numberCell(_ column: String, _ value: Double, bold: Bool) -> String {
            "<c r=\"\(column)\" s=\"\(bold ? 3 : 2)\"><v>\(decimalString(value))</v></c>"
        }

        // Header row
        xml += "<row r=\"1\">"
        for (index, header) in headers.enumerated() {
            xml += textCell("\(columnLetters[index])1", header, bold: true)
        }
        xml += "</row>"

        // Data rows
        for (offset, row) in rows.enumerated() {
            let r = offset + 2
            let bold = row.kind != .lineItem
            xml += "<row r=\"\(r)\">"
            xml += textCell("A\(r)", row.account, bold: bold)
            xml += textCell("B\(r)", row.category, bold: bold)
            xml += textCell("C\(r)", row.description, bold: bold)
            xml += numberCell("D\(r)", row.estimated, bold: bold)
            xml += numberCell("E\(r)", row.actual, bold: bold)
            xml += numberCell("F\(r)", row.remaining, bold: bold)
            xml += textCell("G\(r)", row.notes, bold: bold)
            xml += "</row>"
        }

        xml += "</sheetData></worksheet>"
        return xml
    }

    // MARK: - Minimal ZIP writer (stored/uncompressed entries only)
    //
    // No SPM dependency is used here on purpose: this project has no package
    // manager wiring, and pulling one in risks the same dependency/version
    // conflicts that had to be untangled on CineSched. Stored (uncompressed)
    // ZIP entries are fully valid per the spec and readable by Excel, Numbers,
    // Google Sheets, and `unzip`.

    private struct ZipEntry {
        let name: String
        let data: Data
    }

    private static func crc32(_ bytes: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
        }
        return crc ^ 0xFFFFFFFF
    }

    private static func le16(_ value: UInt16) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    private static func le32(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    private static func makeZip(entries: [ZipEntry]) -> Data {
        var output = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0
        // DOS date for 1980-01-01; DOS timestamps can't represent zero/epoch, so this is
        // the standard placeholder used when the actual mod time doesn't matter.
        let dosDate: UInt16 = 0x21
        let dosTime: UInt16 = 0

        for entry in entries {
            let nameBytes = Data(entry.name.utf8)
            let crc = crc32(entry.data)
            let size = UInt32(entry.data.count)
            let nameLength = UInt16(nameBytes.count)

            var local = Data()
            local.append(le32(0x04034b50))
            local.append(le16(20))
            local.append(le16(0))
            local.append(le16(0))
            local.append(le16(dosTime))
            local.append(le16(dosDate))
            local.append(le32(crc))
            local.append(le32(size))
            local.append(le32(size))
            local.append(le16(nameLength))
            local.append(le16(0))
            local.append(nameBytes)
            local.append(entry.data)

            let localOffset = offset
            output.append(local)
            offset += UInt32(local.count)

            var central = Data()
            central.append(le32(0x02014b50))
            central.append(le16(20))
            central.append(le16(20))
            central.append(le16(0))
            central.append(le16(0))
            central.append(le16(dosTime))
            central.append(le16(dosDate))
            central.append(le32(crc))
            central.append(le32(size))
            central.append(le32(size))
            central.append(le16(nameLength))
            central.append(le16(0))
            central.append(le16(0))
            central.append(le16(0))
            central.append(le16(0))
            central.append(le32(0))
            central.append(le32(localOffset))
            central.append(nameBytes)

            centralDirectory.append(central)
        }

        let cdOffset = offset
        output.append(centralDirectory)

        var eocd = Data()
        eocd.append(le32(0x06054b50))
        eocd.append(le16(0))
        eocd.append(le16(0))
        eocd.append(le16(UInt16(entries.count)))
        eocd.append(le16(UInt16(entries.count)))
        eocd.append(le32(UInt32(centralDirectory.count)))
        eocd.append(le32(cdOffset))
        eocd.append(le16(0))
        output.append(eocd)

        return output
    }
}
