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

                Spacer(minLength: 4)

                Text(value)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .font(.system(size: 12))
    }
}
