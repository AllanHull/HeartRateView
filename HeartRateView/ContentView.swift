import SwiftUI
import HealthKit
import Charts

struct ContentView: View {
    @StateObject private var healthManager = HealthManager()
    
    var body: some View {
        NavigationView {
            VStack {
                // MARK: - Heart Rate Timeline Chart
                Chart(healthManager.heartRates, id: \.uuid) { sample in
                    let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    
                    LineMark(
                        x: .value("Time", sample.endDate),
                        y: .value("BPM", bpm)
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Time", sample.endDate),
                        y: .value("BPM", bpm)
                    )
                    .foregroundStyle(.red)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5))
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 6))
                }
                .frame(height: 250)
                .padding(.horizontal)
                .padding(.top)
                
                // MARK: - List of Samples
                List(healthManager.heartRates, id: \.uuid) { sample in
                    let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    VStack(alignment: .leading) {
                        Text("Heart Rate: \(Int(bpm)) BPM")
                            .font(.headline)
                        Text(sample.endDate, style: .date)
                            .foregroundColor(.secondary)
                        Text(sample.endDate, style: .time)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Heart Rate")
        }
    }
}

#Preview {
    ContentView()
}
