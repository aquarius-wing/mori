import SwiftUI

struct AddChartItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedType = "contribution"
    @State private var selectedColorTheme = "blue"
    @State private var executionStatement = ""
    @State private var goal = 100
    @State private var dateRangeType = "lastYear"
    
    let collectionId: String
    let onSave: (ChartItem) -> Void
    
    let chartTypes = [
        ("contribution", "贡献图"),
        ("progress", "进度图"),
        ("bar", "柱状图")
    ]
    
    let colorThemes = [
        ("blue", "蓝色"),
        ("green", "绿色"),
        ("amber", "琥珀色"),
        ("rose", "玫瑰色"),
        ("purple", "紫色"),
        ("orange", "橙色"),
        ("teal", "青色"),
        ("slate", "灰色"),
        ("red", "红色"),
        ("indigo", "靛蓝色")
    ]
    
    let dateRangeTypes = [
        ("today", "今天"),
        ("thisWeek", "本周"),
        ("thisMonth", "本月"),
        ("thisYear", "今年"),
        ("lastYear", "去年"),
        ("custom", "自定义")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("图表标题", text: $title)
                        .textFieldStyle(.plain)
                    
                    Picker("图表类型", selection: $selectedType) {
                        ForEach(chartTypes, id: \.0) { type, name in
                            Text(name).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("颜色主题", selection: $selectedColorTheme) {
                        ForEach(colorThemes, id: \.0) { theme, name in
                            HStack {
                                Circle()
                                    .fill(getThemeColor(theme))
                                    .frame(width: 16, height: 16)
                                Text(name)
                            }
                            .tag(theme)
                        }
                    }
                }
                
                Section("设置") {
                    Picker("日期范围", selection: $dateRangeType) {
                        ForEach(dateRangeTypes, id: \.0) { type, name in
                            Text(name).tag(type)
                        }
                    }
                    
                    if selectedType == "progress" {
                        Stepper("目标值: \(goal)", value: $goal, in: 1...10000)
                    }
                }
                
                Section("数据源") {
                    TextField("SQL 查询语句", text: $executionStatement, axis: .vertical)
                        .lineLimit(3...8)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                    
                    Text("示例: SELECT date, count FROM daily_activity WHERE date >= date('now', '-1 year')")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("添加图表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChart()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveChart() {
        let settings: ChartItemSetting = selectedType == "contribution" ?
            .contribution(ContributionChartSetting()) :
            .progress(ProgressChartSetting(goal: goal))
        
        let item = ChartItem(
            title: title,
            type: selectedType,
            colorTheme: selectedColorTheme,
            settings: settings,
            belongCollectionId: collectionId,
            executionStatement: executionStatement
        )
        
        onSave(item)
        dismiss()
    }
    
    private func getThemeColor(_ theme: String) -> Color {
        switch theme {
        case "blue":
            return Color("blue-500")
        case "green":
            return Color("green-500")
        case "amber":
            return Color("amber-500")
        case "rose":
            return Color("rose-500")
        case "purple":
            return Color("purple-500")
        case "orange":
            return Color("orange-500")
        case "teal":
            return Color("teal-500")
        case "slate":
            return Color("slate-500")
        case "red":
            return Color("red-500")
        case "indigo":
            return Color("indigo-500")
        default:
            return Color.gray
        }
    }
}

#Preview {
    AddChartItemView(collectionId: "test") { _ in }
} 