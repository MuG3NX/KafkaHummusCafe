import SwiftUI

struct InvoicePreviewView: View {
    @StateObject private var viewModel: InvoicePreviewViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAlert = false
    let onSave: (InvoicePreview) -> Void
    
    init(initialInvoice: InvoicePreview, onSave: @escaping (InvoicePreview) -> Void) {
        let viewModel = InvoicePreviewViewModel()
        viewModel.invoice = initialInvoice
        viewModel.hasVat12 = initialInvoice.vat12Enabled
        viewModel.hasVat21 = initialInvoice.vat21Enabled
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Company Information Section
                    GroupBox("Informace o firmě") {
                        VStack(spacing: 16) {
                            InputField(title: "Název firmy", text: $viewModel.invoice.companyName)
                            InputField(title: "IČO", text: $viewModel.invoice.taxId)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Financial Details Section
                    GroupBox("Finanční detaily") {
                        VStack(spacing: 16) {
                            // Base Price
                            HStack {
                                Text("Základ")
                                    .foregroundColor(ThemeColors.secondary)
                                Spacer()
                                TextField("0,00", value: $viewModel.invoice.basePrice, format: .currency(code: "CZK"))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .onChange(of: viewModel.invoice.basePrice) { _ in
                                        viewModel.updateBasePrice(viewModel.invoice.basePrice)
                                    }
                            }
                            
                            // DPH 12%
                            HStack {
                                Toggle("DPH 12%", isOn: $viewModel.hasVat12)
                                    .foregroundColor(ThemeColors.secondary)
                                if viewModel.hasVat12 {
                                    Spacer()
                                    Text(viewModel.invoice.vat12Amount, format: .number.precision(.fractionLength(2))) 
                                    + Text(" Kč")
                                        .foregroundColor(ThemeColors.accent)
                                }
                            }
                            
                            // DPH 21%
                            HStack {
                                Toggle("DPH 21%", isOn: $viewModel.hasVat21)
                                    .foregroundColor(ThemeColors.secondary)
                                if viewModel.hasVat21 {
                                    Spacer()
                                    Text(viewModel.invoice.vat21Amount, format: .number.precision(.fractionLength(2)))
                                    + Text(" Kč")
                                        .foregroundColor(ThemeColors.accent)
                                }
                            }
                            
                            // Total Price
                            HStack {
                                Text("Celkem")
                                    .fontWeight(.bold)
                                Spacer()
                                Text(viewModel.invoice.totalPrice, format: .number.precision(.fractionLength(2)))
                                + Text(" Kč")
                                    .fontWeight(.bold)
                                    .foregroundColor(ThemeColors.accent)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Dates Section
                    GroupBox("Data") {
                        VStack(spacing: 16) {
                            DatePicker("Datum vystavení", 
                                     selection: $viewModel.invoice.creationDate,
                                     displayedComponents: .date)
                                .foregroundColor(ThemeColors.secondary)
                            
                            DatePicker("Datum splatnosti",
                                     selection: $viewModel.invoice.dueDate,
                                     displayedComponents: .date)
                                .foregroundColor(ThemeColors.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding()
            }
            .background(ThemeColors.background)
            .navigationTitle("Náhled faktury")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Zrušit") {
                        dismiss()
                    }
                    .foregroundColor(ThemeColors.accent)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Uložit") {
                        if viewModel.saveInvoice() {
                            onSave(viewModel.invoice)
                            dismiss()
                        } else {
                            showingAlert = true
                        }
                    }
                    .foregroundColor(ThemeColors.accent)
                }
            }
            .alert("Neplatná data", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Prosím vyplňte název firmy a částku")
            }
        }
    }
} 