import SwiftUI

struct AddCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var order = 0
    let onSave: (ChartCollection) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("集合信息") {
                    TextField("集合标题", text: $title)
                        .textFieldStyle(.plain)
                    
                    Stepper("排序顺序: \(order)", value: $order, in: 0...100)
                }
                
                Section("预览") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            Text(title.isEmpty ? "集合标题" : title)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        Text("排序: \(order)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("创建时间: \(Date().formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
            }
            .navigationTitle("添加集合")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let collection = ChartCollection(title: title, order: order)
                        onSave(collection)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddCollectionView { _ in }
} 