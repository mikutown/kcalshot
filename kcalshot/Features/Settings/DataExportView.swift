import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataExportView: View {
    @Environment(\.modelContext) private var context
    @Query private var meals: [MealEntry]
    @Query private var weights: [WeightEntry]
    @Query private var waters: [WaterEntry]

    @State private var includeThumbnails = false
    @State private var backupURL: URL?
    @State private var mealsCSV: URL?
    @State private var weightsCSV: URL?
    @State private var watersCSV: URL?
    @State private var showImporter = false
    @State private var pendingData: Data?
    @State private var showRestoreChoice = false
    @State private var resultMessage: String?

    var body: some View {
        List {
            Section {
                if let url = mealsCSV {
                    ShareLink(item: url) { Label("三餐记录 CSV", systemImage: "fork.knife") }
                }
                if let url = weightsCSV {
                    ShareLink(item: url) { Label("体重 CSV", systemImage: "scalemass") }
                }
                if let url = watersCSV {
                    ShareLink(item: url) { Label("饮水 CSV", systemImage: "drop") }
                }
            } header: {
                Text("导出 CSV")
            } footer: {
                Text("CSV 便于在表格软件中查看，不含图片。")
            }

            Section {
                Toggle("包含缩略图", isOn: $includeThumbnails)
                if let url = backupURL {
                    ShareLink(item: url) { Label("导出备份文件", systemImage: "square.and.arrow.up") }
                }
                Button {
                    showImporter = true
                } label: {
                    Label("从备份恢复", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("完整备份（JSON）")
            } footer: {
                Text("备份包含全部三餐、目标、体重、饮水与常吃收藏，可用于换机或防丢。含缩略图时文件更大。")
            }
        }
        .navigationTitle("数据导出")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: includeThumbnails) { regenerateBackup() }
        .task(id: "\(meals.count)-\(weights.count)-\(waters.count)") { regenerateCSV() }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .confirmationDialog("如何恢复？", isPresented: $showRestoreChoice, titleVisibility: .visible) {
            Button("合并（保留现有，补入缺失）") { applyRestore(.merge) }
            Button("覆盖（清空后整体导入）", role: .destructive) { applyRestore(.replace) }
            Button("取消", role: .cancel) { pendingData = nil }
        }
        .alert("恢复完成", isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        ), presenting: resultMessage) { _ in
            Button("好", role: .cancel) {}
        } message: { Text($0) }
    }

    private func regenerateBackup() {
        backupURL = try? BackupCodec.exportFile(context: context, includeThumbnails: includeThumbnails)
    }

    private func regenerateCSV() {
        mealsCSV = try? CSVExporter.exportMeals(meals)
        weightsCSV = try? CSVExporter.exportWeights(weights)
        watersCSV = try? CSVExporter.exportWaters(waters)
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            resultMessage = String(localized: "无法读取所选文件")
            return
        }
        pendingData = data
        showRestoreChoice = true
    }

    private func applyRestore(_ mode: RestoreMode) {
        guard let data = pendingData else { return }
        pendingData = nil
        do {
            let s = try BackupCodec.restore(from: data, into: context, mode: mode)
            resultMessage = String(localized: "已导入：三餐 \(s.meals)、体重 \(s.weights)、饮水 \(s.waters)、收藏 \(s.favorites)")
        } catch {
            resultMessage = String(localized: "备份文件无法解析")
        }
    }
}

#Preview {
    NavigationStack { DataExportView() }
        .modelContainer(PreviewData.container)
}
