import Foundation

struct Transaction: Identifiable {
    let id: UUID
    let amount: Double
    let date: Date
    let type: TransactionType
    let paymentMethod: PaymentMethod
    let category: Category
    let notes: String?
    
    enum TransactionType: String, CaseIterable {
        case revenue
        case expense
    }
    
    enum PaymentMethod: String, CaseIterable {
        case cash
        case credit
        case digital
    }
    
    enum Category: String, CaseIterable {
        case ingredients
        case staff
        case utilities
        case other
    }
    
    // Convert from Core Data entity
    init(from entity: TransactionEntity) {
        self.id = entity.id ?? UUID()
        self.amount = entity.amount
        self.date = entity.date ?? Date()
        self.type = TransactionType(rawValue: entity.type ?? "") ?? .expense
        self.paymentMethod = PaymentMethod(rawValue: entity.paymentMethod ?? "") ?? .cash
        self.category = Category(rawValue: entity.category ?? "") ?? .other
        self.notes = entity.notes
    }
} 