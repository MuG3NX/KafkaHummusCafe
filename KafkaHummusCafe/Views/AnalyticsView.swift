import SwiftUI
import Charts

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var showingDatePicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Date Range Selector
                    dateRangeSelector
                    
                    // Payment Split Card
                    paymentSplitCard
                    
                    // Monthly Comparison Card
                    monthlyComparisonCard
                    
                    // Export Button
                    exportButton
                }
                .padding()
            }
            .background(ThemeColors.background)
            .navigationTitle("Analytics")
        }
    }
    
    private var dateRangeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date Range")
                .font(.headline)
                .foregroundColor(ThemeColors.secondary)
            
            HStack {
                ForEach([
                    AnalyticsViewModel.DateRange.week,
                    .month,
                    .quarter,
                    .custom
                ], id: \.self) { range in
                    DateRangeButton(
                        title: range == .custom ? "Custom" : "\(range)".capitalized,
                        isSelected: viewModel.selectedDateRange == range
                    ) {
                        viewModel.selectedDateRange = range
                        if range == .custom {
                            showingDatePicker = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            customDatePicker
        }
    }
    
    private var customDatePicker: some View {
        NavigationView {
            VStack {
                DatePicker("Start Date", selection: $viewModel.startDate, displayedComponents: [.date])
                DatePicker("End Date", selection: $viewModel.endDate, displayedComponents: [.date])
            }
            .padding()
            .navigationTitle("Select Date Range")
            .navigationBarItems(trailing: Button("Done") {
                showingDatePicker = false
            })
        }
    }
    
    private var paymentSplitCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Split")
                .font(.headline)
                .foregroundColor(ThemeColors.secondary)
            
            Chart {
                ForEach(viewModel.paymentSplitData) { data in
                    SectorMark(
                        angle: .value("Amount", data.amount),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(by: .value("Method", data.method.rawValue))
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(ThemeColors.cardBackground)
        .cornerRadius(16)
    }
    
    private var monthlyComparisonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Revenue vs Expenses")
                .font(.headline)
                .foregroundColor(ThemeColors.secondary)
            
            Chart {
                ForEach(viewModel.monthlyData) { data in
                    BarMark(
                        x: .value("Month", data.month),
                        y: .value("Amount", data.revenue)
                    )
                    .foregroundStyle(ThemeColors.accent)
                    
                    BarMark(
                        x: .value("Month", data.month),
                        y: .value("Amount", data.expenses)
                    )
                    .foregroundStyle(Color.red.opacity(0.8))
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(ThemeColors.cardBackground)
        .cornerRadius(16)
    }
    
    private var exportButton: some View {
        Button {
            if let fileURL = viewModel.exportData() {
                let activityVC = UIActivityViewController(
                    activityItems: [fileURL],
                    applicationActivities: nil
                )
                
                // Get the window scene
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    activityVC.popoverPresentationController?.sourceView = rootVC.view
                    rootVC.present(activityVC, animated: true)
                }
            }
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Export as CSV")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(ThemeColors.accent)
            .foregroundColor(.black)
            .cornerRadius(12)
        }
    }
}

struct DateRangeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? ThemeColors.accent : ThemeColors.cardBackground)
                .foregroundColor(isSelected ? .black : ThemeColors.secondary)
                .cornerRadius(8)
        }
    }
} 