import SwiftUI

struct ChartItemEditView: View {
    let chartItem: ChartItem
    let databaseManager: MoriDatabaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var selectedColorTheme: String
    @State private var errorMessage: String?
    @State private var isLoading = false

    // Callback to refresh parent view
    let onSave: () -> Void

    init(chartItem: ChartItem, databaseManager: MoriDatabaseManager, onSave: @escaping () -> Void) {
        self.chartItem = chartItem
        self.databaseManager = databaseManager
        self.onSave = onSave
        self._title = State(initialValue: chartItem.title)
        self._selectedColorTheme = State(initialValue: chartItem.colorTheme)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 自定义头部
                HStack {
                    Button("取消") {
                        dismiss()
                    }
                    .padding(.leading)

                    Spacer()

                    Text("编辑图表")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(
                        title.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty || isLoading
                    )
                    .padding(.trailing)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color(.separator)),
                    alignment: .bottom
                )

                // 简化的表单内容
                ScrollView {
                    VStack(spacing: 20) {
                        // Title section
                        VStack(alignment: .leading, spacing: 12) {

                            VStack(alignment: .leading, spacing: 8) {
                                Text("标题")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                TextField("输入图表标题", text: $title)
                                    .textFieldStyle(.plain)
                                    .frame(height: 40)
                                    .padding(.horizontal)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }

                        // Color theme section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("颜色主题")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)

                            SimpleColorPicker(
                                selectedColor: $selectedColorTheme
                            )
                            .padding(.horizontal)
                        }

                        // Preview section - simplified
                        VStack(alignment: .leading, spacing: 12) {
                            Text("预览")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)

                            ChartItemRowView(
                                    item: ChartItem(
                                        title: "示例图表",
                                        type: "contribution",
                                        colorTheme: selectedColorTheme,
                                        settings: .contribution(ContributionChartSetting()),
                                        belongCollectionId: "test",
                                        executionStatement: ""
                                    ),
                                    previewMode: true
                                )
                                .padding(.horizontal)
                        }

                        // Error message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView("保存中...")
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(radius: 4)
                }
            }
            .background(Color(.secondarySystemBackground))
        }
    }

    private func getPreviewColor() -> Color {
        switch selectedColorTheme {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "teal": return .teal
        case "amber": return .yellow
        case "rose": return .pink
        case "indigo": return .indigo
        case "slate": return .gray
        default: return .blue
        }
    }

    private func saveChanges() {
        // Validate input
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "标题不能为空"
            return
        }

        isLoading = true
        errorMessage = nil

        // Create updated chart item
        var updatedItem = chartItem
        updatedItem.title = trimmedTitle
        updatedItem.colorTheme = selectedColorTheme

        do {
            try databaseManager.updateChartItem(updatedItem)
            onSave()  // Refresh parent view
            dismiss()
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Simple Color Picker

struct SimpleColorPicker: View {
    @Binding var selectedColor: String

    let colors = [
        ("blue", Color.blue),
        ("green", Color.green),
        ("orange", Color.orange),
        ("red", Color.red),
        ("purple", Color.purple),
        ("teal", Color.teal),
        ("amber", Color.yellow),
        ("rose", Color.pink),
        ("indigo", Color.indigo),
        ("slate", Color.gray),
    ]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
            spacing: 12
        ) {
            ForEach(colors, id: \.0) { colorName, color in
                Button(action: {
                    selectedColor = colorName
                }) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                        .aspectRatio(16/10, contentMode: .fit)
                        .overlay {
                            if selectedColor == colorName {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

#Preview {
    ChartItemEditView(
        chartItem: ChartItem(
            title: "示例图表",
            type: "contribution",
            colorTheme: "blue",
            settings: .contribution(ContributionChartSetting()),
            belongCollectionId: "test"
        ),
        databaseManager: try! MoriDatabaseManager(),
        onSave: {
            // onSave callback
        }
    )
}
