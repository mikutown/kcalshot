import SwiftUI

/// 今天页的饮水卡片：展示当日累计/目标与进度，提供快捷加水。
struct WaterCard: View {
    let totalML: Double
    let targetML: Double
    let onAdd: (Double) -> Void
    let onOpenLog: () -> Void

    @State private var showCustom = false

    private var progress: Double {
        targetML > 0 ? min(totalML / targetML, 1) : 0
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("饮水", systemImage: "drop.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tint)
                Spacer()
                Text("\(Int(totalML.rounded())) / \(Int(targetML.rounded())) mL")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress).tint(.accentColor)
            HStack(spacing: 10) {
                quickButton("+200", 200)
                quickButton("+500", 500)
                Button {
                    showCustom = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("自定义饮水量")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onOpenLog() }
        .sheet(isPresented: $showCustom) {
            WaterAmountSheet { onAdd($0) }
        }
    }

    private func quickButton(_ title: LocalizedStringKey, _ amount: Double) -> some View {
        Button {
            onAdd(amount)
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .tint(.accentColor)
    }
}

/// 自定义饮水量输入（喝水卡片与饮水记录页共用）。
struct WaterAmountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 300
    let onSave: (Double) -> Void

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    Text("饮水量")
                    Spacer()
                    TextField("mL", value: $amount, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                    Text("mL").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("记录饮水")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(amount)
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
        }
        .presentationDetents([.height(180)])
    }
}
