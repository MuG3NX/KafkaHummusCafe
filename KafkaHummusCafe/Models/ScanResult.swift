import VisionKit
import CoreGraphics

struct ScanResult {
    let text: String
    let bounds: CGRect
    
    // Add structured data extraction
    var extractedAmount: Double? {
        // Look for currency patterns like $123.45
        let pattern = #"\$?\d+(\.\d{2})?"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            let amountString = text[match].filter { "0123456789.".contains($0) }
            return Double(amountString)
        }
        return nil
    }
    
    var extractedDate: Date? {
        // Look for common date formats
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormats = [
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "yyyy-MM-dd"
        ]
        
        for format in dateFormatter.dateFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: text) {
                return date
            }
        }
        return nil
    }
    
    init(from recognizedItem: RecognizedItem) {
        switch recognizedItem {
        case .text(let text):
            self.text = text.transcript
            self.bounds = CGRect(
                x: text.bounds.topLeft.x,
                y: text.bounds.topLeft.y,
                width: text.bounds.topRight.x - text.bounds.topLeft.x,
                height: text.bounds.bottomLeft.y - text.bounds.topLeft.y
            )
        default:
            self.text = ""
            self.bounds = .zero
        }
    }
}

private extension DateFormatter {
    var dateFormats: [String] {
        get { [] }
        set { }
    }
} 