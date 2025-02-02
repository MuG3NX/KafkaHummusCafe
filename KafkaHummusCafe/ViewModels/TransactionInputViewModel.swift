import SwiftUI
import VisionKit
import CoreData

class TransactionInputViewModel: ObservableObject {
    @Published var amount: String = ""
    @Published var date = Date()
    @Published var type: Transaction.TransactionType = .revenue
    @Published var paymentMethod: Transaction.PaymentMethod = .cash
    @Published var category: Transaction.Category = .ingredients
    @Published var notes: String = ""
    @Published var showingScanner = false
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var showingInvoicePreview = false
    @Published var scannedText: String = ""
    @Published var scannedInvoice: InvoicePreview?
    
    private let viewContext: NSManagedObjectContext
    private let invoicePreviewViewModel = InvoicePreviewViewModel()
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
    }
    
    func saveTransaction() {
        guard let amountDouble = Double(amount) else {
            alertMessage = "Please enter a valid amount"
            showingAlert = true
            return
        }
        
        let entity = TransactionEntity(context: viewContext)
        entity.id = UUID()
        entity.amount = amountDouble
        entity.date = date
        entity.type = type.rawValue
        entity.paymentMethod = paymentMethod.rawValue
        entity.category = category.rawValue
        entity.notes = notes.isEmpty ? nil : notes
        
        do {
            try viewContext.save()
            // Clear form after successful save
            clearForm()
        } catch {
            alertMessage = "Error saving transaction: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func clearForm() {
        amount = ""
        date = Date()
        type = .revenue
        paymentMethod = .cash
        category = .ingredients
        notes = ""
    }
    
    func processScannedInvoice(_ recognizedItem: RecognizedItem) {
        if case .text(let text) = recognizedItem {
            print("📱 Processing invoice text:")
            print("   - text: \(text.transcript)")
            let viewModel = InvoicePreviewViewModel()
            viewModel.parseScannedText(text.transcript)
            scannedInvoice = viewModel.invoice
            showingInvoicePreview = true
        }
    }
    
    func processInvoiceImage(_ image: UIImage) {
        // Create a new invoice preview view model to handle the processing
        invoicePreviewViewModel.onSave = { [weak self] invoice in
            // When invoice is processed, update our transaction
            self?.amount = String(format: "%.2f", invoice.basePrice + invoice.vat12Amount)
            self?.notes = "Invoice from: \(invoice.companyName)\nIČO: \(invoice.taxId)"
            self?.category = .ingredients  // Default for FANY invoices
            self?.type = .expense
        }
        
        // Process the image
        invoicePreviewViewModel.processInvoiceImage(image)
        
        // Show the invoice preview
        scannedInvoice = invoicePreviewViewModel.invoice
        showingInvoicePreview = true
    }
    
    func handleSavedInvoice(_ invoice: InvoicePreview) {
        // Update transaction with invoice data
        amount = String(format: "%.2f", invoice.basePrice + invoice.vat12Amount)
        notes = "Invoice from: \(invoice.companyName)\nIČO: \(invoice.taxId)"
        showingInvoicePreview = false
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
} 