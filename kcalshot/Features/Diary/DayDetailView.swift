import SwiftUI
import SwiftData

/// 某一天的饮食记录详情：列出当天三餐，可编辑/删除，也可为这一天新增记录。
struct DayDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MealEntry.date) private var allEntries: [MealEntry]

    let date: Date

    @State private var showCapture = false
    @State private var captureMode: CaptureView.InputMode = .photo
    @State private var showSourceDialog = false
    @State private var pickedImage: UIImage?

    private var dayEntries: [MealEntry] { allEntries.onSameDay(as: date) }

    /// 新记录归属到这一天：今天用当前时间，其他天用当天正午。
    private var captureTargetDate: Date {
        if CalendarMath.calendar.isDateInToday(date) { return .now }
        return CalendarMath.calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    var body: some View {
        Group {
            if dayEntries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .navigationTitle(Self.titleFormatter.string(from: date))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showSourceDialog = true } label: {
                        Label("拍照识别", systemImage: "camera.fill")
                    }
                    Button { captureMode = .text; showCapture = true } label: {
                        Label("文字记录", systemImage: "text.cursor")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .photoSourcePicker(isPresented: $showSourceDialog) { image in
            pickedImage = image
            captureMode = .photo
            showCapture = true
        }
        .onChange(of: showCapture) { _, isShown in
            if !isShown { pickedImage = nil }
        }
        .sheet(isPresented: $showCapture) {
            CaptureView(mode: captureMode, initialImage: pickedImage, targetDate: captureTargetDate)
        }
    }

    private var entryList: some View {
        List {
            Section {
                LabeledContent("当日合计", value: "\(Int(NutritionTotals(dayEntries).calories.rounded())) kcal")
            }
            ForEach(dayEntries.groupedByMeal(), id: \.meal) { group in
                Section(group.meal.displayName) {
                    ForEach(group.entries) { entry in
                        NavigationLink {
                            MealEditView(entry: entry, isNew: false)
                        } label: {
                            MealEntryRow(entry: entry)
                        }
                    }
                    .onDelete { offsets in delete(group.entries, offsets) }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("这一天还没有记录", systemImage: "fork.knife")
        } description: {
            Text("请使用右上角「+」为这一天添加记录")
        } actions: {
            Button { showSourceDialog = true } label: {
                Label("拍照识别", systemImage: "camera.fill")
            }
            .buttonStyle(.borderedProminent)
            Button { captureMode = .text; showCapture = true } label: {
                Label("文字记录", systemImage: "text.cursor")
            }
            .buttonStyle(.bordered)
        }
    }

    private func delete(_ entries: [MealEntry], _ offsets: IndexSet) {
        for index in offsets { context.delete(entries[index]) }
    }

    private static let titleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("MMMMdEEEE")
        return f
    }()
}
