import SwiftUI
import VisionKit

struct TransactionInputView: View {
    @StateObject private var viewModel = TransactionInputViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Type Selector
                    segmentedTypeSelector
                    
                    // Amount and Date
                    amountDateSection
                    
                    // Payment Method
                    paymentMethodSection
                    
                    // Category
                    categorySection
                    
                    // Notes
                    notesSection
                    
                    // Scan Invoice Button
                    scanInvoiceButton
                    
                    // Save Button
                    saveButton
                }
                .padding()
            }
            .background(ThemeColors.background)
            .navigationTitle(viewModel.type == .revenue ? "Add Revenue" : "Log Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ThemeColors.accent)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: sourceType) { image in
                    viewModel.processInvoiceImage(image)
                }
            }
            .sheet(isPresented: $viewModel.showingInvoicePreview) {
                if let scannedInvoice = viewModel.scannedInvoice {
                    InvoicePreviewView(initialInvoice: scannedInvoice) { invoice in
                        viewModel.handleSavedInvoice(invoice)
                    }
                }
            }
            .alert("Notice", isPresented: $viewModel.showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage)
            }
        }
    }
    
    private var segmentedTypeSelector: some View {
        Picker("Transaction Type", selection: $viewModel.type) {
            Text("Revenue").tag(Transaction.TransactionType.revenue)
            Text("Expense").tag(Transaction.TransactionType.expense)
        }
        .pickerStyle(.segmented)
        .padding(.vertical)
    }
    
    private var amountDateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            InputField(title: "Amount", text: $viewModel.amount)
                .keyboardType(.decimalPad)
            
            DatePicker("Date", selection: $viewModel.date, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .foregroundColor(ThemeColors.secondary)
        }
    }
    
    private var paymentMethodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment Method")
                .foregroundColor(ThemeColors.secondary)
            
            HStack {
                ForEach([Transaction.PaymentMethod.cash, .credit, .digital], id: \.self) { method in
                    PaymentMethodButton(
                        method: method,
                        isSelected: viewModel.paymentMethod == method,
                        action: { viewModel.paymentMethod = method }
                    )
                }
            }
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .foregroundColor(ThemeColors.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach([
                        Transaction.Category.ingredients,
                        .staff,
                        .utilities,
                        .other
                    ], id: \.self) { category in
                        CategoryButton(
                            category: category,
                            isSelected: viewModel.category == category,
                            action: { viewModel.category = category }
                        )
                    }
                }
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .foregroundColor(ThemeColors.secondary)
            
            TextEditor(text: $viewModel.notes)
                .frame(height: 100)
                .padding(8)
                .background(ThemeColors.cardBackground)
                .cornerRadius(12)
        }
    }
    
    private var scanInvoiceButton: some View {
        HStack(spacing: 20) {
            Button {
                // Check if camera is available
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    sourceType = .camera
                    showingImagePicker = true
                } else {
                    viewModel.alertMessage = "Camera is not available"
                    viewModel.showingAlert = true
                }
            } label: {
                HStack {
                    Image(systemName: "camera")
                    Text("Take Photo")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ThemeColors.cardBackground)
                .foregroundColor(ThemeColors.accent)
                .cornerRadius(12)
            }
            
            Button {
                sourceType = .photoLibrary
                showingImagePicker = true
            } label: {
                HStack {
                    Image(systemName: "photo")
                    Text("Choose Photo")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ThemeColors.cardBackground)
                .foregroundColor(ThemeColors.accent)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    private var saveButton: some View {
        Button {
            viewModel.saveTransaction()
        } label: {
            Text("Save Transaction")
                .frame(maxWidth: .infinity)
                .padding()
                .background(ThemeColors.accent)
                .foregroundColor(.black)
                .cornerRadius(12)
        }
    }
}

// Custom Input Field
struct InputField: View {
    let title: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundColor(ThemeColors.secondary)
            
            TextField("", text: $text)
                .padding()
                .background(ThemeColors.cardBackground)
                .cornerRadius(12)
                .foregroundColor(ThemeColors.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ThemeColors.accent.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// Payment Method Button
struct PaymentMethodButton: View {
    let method: Transaction.PaymentMethod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(method.rawValue.capitalized)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? ThemeColors.accent : ThemeColors.cardBackground)
                .foregroundColor(isSelected ? .black : ThemeColors.secondary)
                .cornerRadius(8)
        }
    }
}

// Category Button
struct CategoryButton: View {
    let category: Transaction.Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.rawValue.capitalized)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? ThemeColors.accent : ThemeColors.cardBackground)
                .foregroundColor(isSelected ? .black : ThemeColors.secondary)
                .cornerRadius(8)
        }
    }
}

// Add ImagePicker struct
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        
        // Additional camera settings
        if sourceType == .camera {
            picker.cameraCaptureMode = .photo
            picker.cameraDevice = .rear
            picker.showsCameraControls = true
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 