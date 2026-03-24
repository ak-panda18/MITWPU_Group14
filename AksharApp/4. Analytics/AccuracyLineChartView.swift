import SwiftUI
import Charts

struct AccuracyLineChartView: View {

    let title: String
    let data: [AccuracyPoint]

    @State private var selectedPoint: AccuracyPoint?

    var body: some View {
        VStack(spacing: 12) {

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Chart {
                ForEach(data) { point in
                    LineMark(
                        x: .value("Day", point.dateLabel),
                        y: .value("Accuracy", point.value)
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Day", point.dateLabel),
                        y: .value("Accuracy", point.value)
                    )
                }

                if let selected = selectedPoint {
                    PointMark(
                        x: .value("Day", selected.dateLabel),
                        y: .value("Accuracy", selected.value)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(100)
                    .annotation(position: .top, alignment: .center) {
                        Text("\(selected.value)%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(6)
                            .shadow(radius: 2)
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            if let day: String = proxy.value(atX: location.x),
                               let match = data.first(where: { $0.dateLabel == day }) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedPoint = match
                                }
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}
