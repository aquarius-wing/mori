import SwiftUI

struct ChartView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("ChartView")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Chart")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    ChartView()
} 