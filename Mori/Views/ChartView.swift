import SwiftUI

struct ChartView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var gameDataService = GameDataService.shared
    
    private var contributionColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.1, green: 0.1, blue: 0.12), // Empty/0 hours
                Color(red: 0.0, green: 0.5, blue: 0.3),  // Low (< 1 hour)
                Color(red: 0.0, green: 0.7, blue: 0.4),  // Medium (1-3 hours)
                Color(red: 0.2, green: 0.8, blue: 0.5),  // High (3-5 hours)
                Color(red: 0.4, green: 1.0, blue: 0.6)   // Very High (5+ hours)
            ]
        } else {
            return [
                Color(red: 0.93, green: 0.93, blue: 0.93), // Empty/0 hours
                Color(red: 0.78, green: 0.92, blue: 0.85),  // Low (< 1 hour)
                Color(red: 0.53, green: 0.85, blue: 0.68),  // Medium (1-3 hours)
                Color(red: 0.25, green: 0.68, blue: 0.42),  // High (3-5 hours)
                Color(red: 0.13, green: 0.55, blue: 0.25)   // Very High (5+ hours)
            ]
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Stats Cards
                    statisticsCards
                    
                    // Contribution Chart
                    contributionChart
                    
                    // Legend
                    legendView
                    
                    // Recent Activities
                    recentActivitiesView
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("游戏时间统计")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                gameDataService.loadGameData()
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("🎮 游戏活动追踪")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("基于日历事件的游戏时间可视化")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Statistics Cards
    private var statisticsCards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            StatCard(
                title: "总游戏时间",
                value: String(format: "%.1f", gameDataService.getTotalGameHours()),
                unit: "小时",
                icon: "gamecontroller.fill",
                color: .blue
            )
            
            StatCard(
                title: "平均每日",
                value: String(format: "%.1f", gameDataService.getAverageHoursPerDay()),
                unit: "小时",
                icon: "chart.bar.fill",
                color: .green
            )
            
            StatCard(
                title: "单日最高",
                value: String(format: "%.1f", gameDataService.getMaxHoursInDay()),
                unit: "小时",
                icon: "trophy.fill",
                color: .orange
            )
            
            StatCard(
                title: "活跃天数",
                value: "\(gameDataService.gameActivities.count)",
                unit: "天",
                icon: "calendar.badge.clock",
                color: .purple
            )
        }
    }
    
    // MARK: - Contribution Chart
    private var contributionChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("年度游戏活动图")
                .font(.headline)
                .fontWeight(.semibold)
            
            if gameDataService.isLoading {
                ProgressView("加载中...")
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else if let errorMessage = gameDataService.errorMessage {
                ErrorView(message: errorMessage) {
                    gameDataService.loadGameData()
                }
                .frame(height: 200)
            } else {
                CustomContributionGridView(activities: gameDataService.gameActivities)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Legend View
    private var legendView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("图例")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                Text("少")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { level in
                        Rectangle()
                            .fill(contributionColors[level])
                            .frame(width: 11, height: 11)
                            .cornerRadius(2)
                    }
                }
                
                Text("多")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Hours legend
                VStack(alignment: .trailing, spacing: 2) {
                    Text("0h  <1h  1-3h  3-5h  5h+")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Recent Activities View
    private var recentActivitiesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近活动")
                .font(.headline)
                .fontWeight(.semibold)
            
            if gameDataService.gameActivities.isEmpty {
                Text("暂无游戏活动数据")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(gameDataService.gameActivities.suffix(10).reversed().enumerated()), id: \.offset) { index, activity in
                        ActivityRow(activity: activity)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ActivityRow: View {
    let activity: GameActivityData
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: activity.date))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("游戏时长")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f", activity.hours))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("小时")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重试", action: onRetry)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ChartView()
}