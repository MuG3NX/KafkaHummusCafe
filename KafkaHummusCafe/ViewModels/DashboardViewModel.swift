import Foundation
import SwiftUI
import Charts
import CoreData

class DashboardViewModel: ObservableObject {
    @Published var monthlyRevenue: Double = 0
    @Published var activeExpenses: Double = 0
    @Published var netProfit: Double = 0
    @Published var selectedChartMetric: ChartMetric = .revenue
    @Published var recentTransactions: [Transaction] = []
    
    private let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
        loadData()
    }
    
    func loadData() {
        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TransactionEntity.date, ascending: false)]
        
        do {
            let entities = try viewContext.fetch(fetchRequest)
            recentTransactions = entities.map { entity in Transaction(from: entity) }
            
            // Calculate totals
            let currentMonth = Calendar.current.component(.month, from: Date())
            let monthlyTransactions = entities.filter {
                guard let date = $0.date else { return false }
                return Calendar.current.component(.month, from: date) == currentMonth
            }
            
            monthlyRevenue = monthlyTransactions
                .filter { $0.type == Transaction.TransactionType.revenue.rawValue }
                .reduce(0) { $0 + $1.amount }
            
            activeExpenses = monthlyTransactions
                .filter { $0.type == Transaction.TransactionType.expense.rawValue }
                .reduce(0) { $0 + $1.amount }
            
            netProfit = monthlyRevenue - activeExpenses
            
        } catch {
            print("Error fetching transactions: \(error)")
        }
    }
    
    enum ChartMetric {
        case revenue
        case expense
        case paymentSplit
    }
    
    struct WeeklyDataPoint: Identifiable {
        let id = UUID()
        let day: String
        let amount: Double
    }
    
    var weeklyData: [WeeklyDataPoint] = [
        WeeklyDataPoint(day: "Mon", amount: 1200),
        WeeklyDataPoint(day: "Tue", amount: 1500),
        WeeklyDataPoint(day: "Wed", amount: 1100),
        WeeklyDataPoint(day: "Thu", amount: 1800),
        WeeklyDataPoint(day: "Fri", amount: 2200),
        WeeklyDataPoint(day: "Sat", amount: 2500),
        WeeklyDataPoint(day: "Sun", amount: 2260)
    ]
    
    func loadRecentTransactions() {
        // TODO: Load from Core Data
    }
} 
