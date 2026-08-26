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
    @State private var selectedPhoto: PhotoSelection?

    private let orangeDark = Color(red: 180.0/255, green: 118.0/255, blue: 0)
    private let coralDark = Color(red: 214.0/255, green: 74.0/255, blue: 42.0/255)

    private var dayEntries: [MealEntry] { allEntries.onSameDay(as: date) }
    private var dayTotals: NutritionTotals { NutritionTotals(dayEntries) }

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
        .background(Color.appBackground)
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
        .photoSourcePicker(isPresented: $showSourceDialog) { photo in
            selectedPhoto = photo
            captureMode = .photo
            showCapture = true
        }
        .onChange(of: showCapture) { _, isShown in
            if !isShown { selectedPhoto = nil }
        }
        .sheet(isPresented: $showCapture) {
            CaptureView(mode: captureMode, selectedPhoto: selectedPhoto, targetDate: captureTargetDate)
        }
    }

    private var entryList: some View {
        List {
            Section {
                daySummaryCard
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            ForEach(dayEntries.groupedByMeal(), id: \.meal) { group in
                Section {
                    ForEach(group.entries) { entry in
                        NavigationLink {
                            MealEditView(entry: entry, isNew: false)
                        } label: {
                            MealEntryRow(entry: entry)
                        }
                    }
                    .onDelete { offsets in delete(group.entries, offsets) }
                } header: {
                    mealHeader(group)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    private var daySummaryCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("当日合计")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                Spacer()
                (Text("\(Int(dayTotals.calories.rounded()))")
                    .font(.system(size: 28, weight: .bold)).monospacedDigit()
                 + Text(" kcal").font(.subheadline).foregroundStyle(Color.inkTertiary))
                    .foregroundStyle(Color.inkPrimary)
            }
            HStack(spacing: 10) {
                macroChip("蛋白质", dayTotals.protein, tint: .brandGreen, label: .brandGreenDeep)
                macroChip("脂肪", dayTotals.fat, tint: .brandCoral, label: coralDark)
                macroChip("碳水", dayTotals.carbs, tint: .brandOrange, label: orangeDark)
            }
        }
        .cardStyle()
    }

    private func macroChip(_ name: String, _ value: Double, tint: Color, label: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value.rounded()))g")
                .font(.system(size: 16, weight: .heavy)).monospacedDigit()
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func mealHeader(_ group: (meal: MealType, entries: [MealEntry])) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(group.meal.displayName)
                .font(.headline)
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            Text("\(Int(NutritionTotals(group.entries).calories.rounded())) kcal")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.brandGreenDeep)
        }
        .textCase(nil)
        .padding(.top, 6)
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
        .tint(.brandGreen)
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
