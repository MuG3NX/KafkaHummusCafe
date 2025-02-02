import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showingTransactionInput = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Bar
                    statsBar
                    
                    // Weekly Trend Card
                    weeklyTrendCard
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Recent Entries
                    recentEntriesSection
                }
                .padding()
            }
            .background(ThemeColors.background)
            .navigationTitle("Dashboard")
            .sheet(isPresented: $showingTransactionInput) {
                TransactionInputView()
            }
        }
    }
    
    private var statsBar: some View {
        HStack {
            StatCard(title: "Monthly Revenue", value: "$\(Int(viewModel.monthlyRevenue))", icon: "arrow.up.right")
            StatCard(title: "Active Expenses", value: "$\(Int(viewModel.activeExpenses))", icon: "arrow.down.right")
            StatCard(title: "Net Profit", value: "$\(Int(viewModel.netProfit))", icon: "dollarsign")
        }
    }
    
    private var weeklyTrendCard: some View {
        VStack(alignment: .leading) {
            Text("Weekly Trend")
                .font(.headline)
                .foregroundColor(ThemeColors.secondary)
            
            Picker("Metric", selection: $viewModel.selectedChartMetric) {
                Text("Revenue").tag(DashboardViewModel.ChartMetric.revenue)
                Text("Expenses").tag(DashboardViewModel.ChartMetric.expense)
                Text("Payment Split").tag(DashboardViewModel.ChartMetric.paymentSplit)
            }
            .pickerStyle(.segmented)
            .padding(.vertical)
            
            Chart {
                ForEach(viewModel.weeklyData) { dataPoint in
                    LineMark(
                        x: .value("Day", dataPoint.day),
                        y: .value("Amount", dataPoint.amount)
                    )
                    .foregroundStyle(ThemeColors.accent)
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(ThemeColors.cardBackground)
        .cornerRadius(16)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(ThemeColors.secondary)
            
            HStack(spacing: 12) {
                QuickActionButton(title: "Add Revenue", icon: "plus.circle.fill") {
                    showingTransactionInput = true
                }
                
                QuickActionButton(title: "Log Expense", icon: "minus.circle.fill") {
                    showingTransactionInput = true
                }
                
                QuickActionButton(title: "Export Report", icon: "square.and.arrow.up.fill") {
                    // Handle export
                }
            }
        }
    }
    
    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Entries")
                .font(.headline)
                .foregroundColor(ThemeColors.secondary)
            
            ForEach(viewModel.recentTransactions.prefix(5)) { transaction in
                TransactionRow(transaction: transaction)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption)
            .foregroundColor(ThemeColors.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ThemeColors.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ThemeColors.cardBackground)
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(ThemeColors.cardBackground)
            .foregroundColor(ThemeColors.accent)
            .cornerRadius(12)
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.date, style: .date)
                    .font(.subheadline)
                Text(transaction.category.rawValue)
                    .font(.caption)
            }
            
            Spacer()
            
            Text(String(format: "$%.2f", transaction.amount))
                .fontWeight(.semibold)
                .foregroundColor(transaction.type == .revenue ? .green : .red)
        }
        .padding()
        .background(ThemeColors.cardBackground)
        .cornerRadius(12)
    }
} 