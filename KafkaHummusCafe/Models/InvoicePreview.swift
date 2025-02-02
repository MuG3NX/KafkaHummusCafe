import Foundation  // Add this for Date

struct InvoicePreview {
    var companyName: String = ""
    var taxId: String = ""
    
    var basePrice: Double = 0
    var vat12Enabled: Bool = false
    var vat21Enabled: Bool = false
    var vat12Amount: Double = 0
    var vat21Amount: Double = 0
    
    var creationDate: Date = Date()
    var dueDate: Date = Date().addingTimeInterval(14 * 24 * 60 * 60) // Default 14 days
    
    var totalPrice: Double {
        basePrice + vat12Amount + vat21Amount
    }
} 