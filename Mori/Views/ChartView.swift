import SwiftUI

struct ChartView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(ChartItem.sampleData.indices, id: \.self) { index in
                        ChartItemView(chartItem: ChartItem.sampleData[index])
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
            .navigationTitle("数据图表")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.gray.opacity(0.05))
        }
    }
}

#Preview {
    ChartView()
}