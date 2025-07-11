import SwiftUI

struct CollectionCardView: View {
    let collection: ChartCollection
    @State private var chartItemCount = 0
    
    var body: some View {
        NavigationLink(destination: CollectionDetailView(collection: collection)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("\(chartItemCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(collection.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                HStack {
                    Text("创建于")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(collection.creationDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadChartItemCount()
        }
    }
    
    private func loadChartItemCount() {
        // TODO: Load chart item count from database
        chartItemCount = 0
    }
}

#Preview {
    CollectionCardView(collection: ChartCollection(title: "示例集合", order: 0))
        .frame(width: 160, height: 140)
        .padding()
} 