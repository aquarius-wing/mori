import SwiftUI

struct ChartItemView: View {
    @Environment(\.colorScheme) var colorScheme
    
    let chartItem: ChartItemViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart Header
            chartHeaderView
            
            // Chart Content
            chartContentView
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(red: 0.08, green: 0.08, blue: 0.10) : Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Subviews
    
    private var chartHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chartItem.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(chartTypeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Color scheme indicator
            colorSchemeIndicator
        }
    }
    
    private var chartContentView: some View {
        Group {
            switch chartItem.type {
            case .contribution:
                CustomContributionGridView(
                    activities: convertToContributionData(chartItem.data),
                    chartColorScheme: chartItem.colorScheme
                )
                .padding(16)
                
            case .line, .bar, .pie, .progress:
                // Placeholder for other chart types
                chartPlaceholderView
            }
        }
    }
    
    private var colorSchemeIndicator: some View {
        HStack(spacing: 4) {
            let colors = chartItem.colorScheme.getContributionColors()
            
            ForEach(1..<colors.count, id: \.self) { index in
                Circle()
                    .fill(colors[index])
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.17) : Color(red: 0.95, green: 0.95, blue: 0.97))
        )
    }
    
    private var chartPlaceholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Chart Type: \(chartItem.type.displayName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.14) : Color(red: 0.98, green: 0.98, blue: 0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(16)
    }
    
    private var chartTypeDescription: String {
        return "\(chartItem.type.displayName) • \(chartItem.colorScheme.displayName) Theme"
    }
    
    // MARK: - Helper Methods
    
    // Convert chart data array to ContributionGridData array for contribution grid
    private func convertToContributionData(_ data: [Int]) -> [ContributionGridData] {
        let calendar = Calendar.current
        let today = Date()
        
        return data.enumerated().map { index, value in
            // Go back from today to create dates for the past year
            let date = calendar.date(byAdding: .day, value: -(data.count - 1 - index), to: today) ?? today
            return ContributionGridData(date: date, count: Double(value))
        }
    }
}

#Preview {
    ScrollView {
        LazyVStack(spacing: 20) {
            // Show different chart items with various color schemes
            ForEach(ChartItemViewModel.sampleData.prefix(6), id: \.id) { chartItem in
                ChartItemView(chartItem: chartItem)
            }
        }
        .padding(.vertical)
    }
    .background(Color.gray.opacity(0.05))
} 