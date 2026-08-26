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
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.waterBlue.opacity(0.14))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "drop.fill")
                            .font(.title3)
                            .foregroundStyle(Color.waterBlue)
                    }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("饮水")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.inkPrimary)
                        Spacer()
                        Text("\(Int(totalML.rounded())) / \(Int(targetML.rounded())) mL")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(Color.inkTertiary)
                    }
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.06))
                        GeometryReader { geo in
                            Capsule()
                                .fill(Color.waterBlue)
                                .frame(width: max(6, geo.size.width * progress))
                        }
                    }
                    .frame(height: 8)
                }
            }
            HStack(spacing: 10) {
                quickButton("+200", 200)
                quickButton("+500", 500)
                Button {
                    showCustom = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.waterBlue)
                .background(Color.waterBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("自定义饮水量")
            }
        }
        .cardStyle()
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
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.waterBlue)
        .background(Color.waterBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .tint(.brandGreen)
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
                    .fontWeight(.bold)
                    .disabled(amount <= 0)
                }
            }
        }
        .presentationDetents([.height(180)])
    }
}
