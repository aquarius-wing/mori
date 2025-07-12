import SwiftUI

struct DebugActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(Color("foreground"))
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color("muted-foreground"))
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color("muted-foreground"))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DebugActionRow(
        title: "示例操作",
        subtitle: "这是一个示例操作描述",
        icon: "gear.circle.fill",
        color: .blue
    ) {
        // Action
    }
    .padding()
} 