import SwiftUI
import GRDB

struct ChartView: View {
    @StateObject private var databaseManager: MoriDatabaseManager
    @State private var collections: [ChartCollection] = []
    @State private var showingAddCollection = false
    @State private var errorMessage: String?
    
    init() {
        do {
            let manager = try MoriDatabaseManager()
            self._databaseManager = StateObject(wrappedValue: manager)
        } catch {
            // Fallback - this shouldn't happen in normal usage
            self._databaseManager = StateObject(wrappedValue: try! MoriDatabaseManager())
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if collections.isEmpty {
                    // Empty state content
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("暂无图表集合")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("点击右上角的添加按钮创建您的第一个图表集合")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                } else {
                    // Collections grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(collections, id: \.id) { collection in
                                CollectionCardView(collection: collection)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
                
                // Error message display
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
            .navigationTitle("图表集合")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddCollection = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddCollection) {
                AddCollectionView { collection in
                    saveCollection(collection)
                }
            }
            .onAppear {
                loadCollections()
            }
        }
    }
    
    // MARK: - Database Operations
    
    private func loadCollections() {
        do {
            collections = try databaseManager.getAllCollections()
            errorMessage = nil
        } catch {
            errorMessage = "加载集合失败: \(error.localizedDescription)"
        }
    }
    
    private func saveCollection(_ collection: ChartCollection) {
        do {
            try databaseManager.createCollection(collection)
            loadCollections()
            errorMessage = nil
        } catch {
            errorMessage = "保存集合失败: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ChartView()
}