import SwiftUI

struct PowerRowView: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var wrapsValue: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 18)
                .padding(.top, 1)

            if wrapsValue {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .fontWeight(.medium)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(label)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(value)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
        }
        .font(.system(size: 12))
    }
}
