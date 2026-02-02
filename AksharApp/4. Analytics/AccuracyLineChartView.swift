//
//  AccuracyLineChartView.swift
//  AksharApp
//
//  Created by Akshita Panda on 13/01/26.
//
import SwiftUI
import Charts

struct AccuracyLineChartView: View {

    let title: String
    let data: [AccuracyPoint]

    var body: some View {
        VStack(spacing: 12) {

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Chart(data) { point in
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
            .chartYScale(domain: 0...100)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}
