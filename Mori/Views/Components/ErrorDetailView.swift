import SwiftUI
import Foundation

// MARK: - Error Detail View

struct ErrorDetailView: View {
    let errorDetail: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.red)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Error Details")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Complete error information")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Divider()
                        .background(Color.white.opacity(0.2))
                }

                // Error content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Error details
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Error Information:")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text(errorDetail)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                                .multilineTextAlignment(.leading)
                        }

                        // Copy button
                        HStack {
                            Spacer()
                            Button(action: {
                                UIPasteboard.general.string = errorDetail
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                    Text("Copy Error")
                                        .font(.body)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.2))
                                )
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
            .navigationBarHidden(true)
        }
    }
} 