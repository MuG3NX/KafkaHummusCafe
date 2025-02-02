import SwiftUI
import Charts
import UniformTypeIdentifiers

class AnalyticsViewModel: ObservableObject {
    @Published var selectedDateRange: DateRange = .month
    @Published var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var endDate = Date()
    
    enum DateRange {
        case week
        case month
        case quarter
        case custom
    }
    
    struct PaymentSplit: Identifiable {
        let id = UUID()
        let method: Transaction.PaymentMethod
        let amount: Double
    }
    
    // Sample data - replace with actual data from Core Data
    var paymentSplitData: [PaymentSplit] = [
        PaymentSplit(method: .cash, amount: 4500),
        PaymentSplit(method: .credit, amount: 6200),
        PaymentSplit(method: .digital, amount: 1860)
    ]
    
    struct MonthlyComparison: Identifiable {
        let id = UUID()
        let month: String
        let revenue: Double
        let expenses: Double
    }
    
    var monthlyData: [MonthlyComparison] = [
        MonthlyComparison(month: "Jan", revenue: 12500, expenses: 8200),
        MonthlyComparison(month: "Feb", revenue: 14200, expenses: 7800),
        MonthlyComparison(month: "Mar", revenue: 15800, expenses: 8900)
    ]
    
    func exportData() -> URL? {
        let csvString = createCSVString()
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("transactions.csv")
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing CSV: \(error)")
            return nil
        }
    }
    
    private func createCSVString() -> String {
        var csvString = "Date,Type,Amount,Payment Method,Category,Notes\n"
        
        // Add sample data or real data from Core Data
        for data in monthlyData {
            csvString += "\(data.month),Revenue,\(data.revenue),Cash,Other,\n"
            csvString += "\(data.month),Expense,\(data.expenses),Cash,Other,\n"
        }
        
        return csvString
    }
} 