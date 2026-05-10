//
//  ViewModel.swift
//  warvba.thanin.test
//

import Foundation
internal import Combine

// MARK: - GRAPH MODEL

struct ChartPoint: Identifiable {

    let id = UUID()

    let day: String

    let value: Double
}

// MARK: - VIEW MODEL

@MainActor
final class AirflowViewModel: ObservableObject {

    // MARK: PUBLISHED

    @Published var dags: [AirflowDAG] = []

    @Published var dagRuns: [AirflowDagRun] = []

    @Published var graphData: [ChartPoint] = []

    @Published var isLoading = false

    @Published var errorMessage: String?

    // MARK: INIT

    init() {

    }

    // MARK: SUCCESS COUNT

    var successCount: Int {

        dagRuns.filter {

            $0.state.lowercased() == "success"

        }.count
    }

    // MARK: FAILED COUNT

    var failedCount: Int {

        dagRuns.filter {

            $0.state.lowercased() == "failed"

        }.count
    }

    // MARK: RUNNING COUNT

    var runningCount: Int {

        dagRuns.filter {

            $0.state.lowercased() == "running"

        }.count
    }

    // MARK: LOAD DAGS

    func loadDAGs() async {

        isLoading = true

        defer {

            isLoading = false
        }

        do {

            let response = try await AirflowAPIService.shared.fetchDAGs()

            dags = response

            print("TOTAL DAGS = \(dags.count)")

        } catch {

            errorMessage = error.localizedDescription

            print("LOAD DAGS ERROR = \(error)")
        }
    }

    // MARK: LOAD DAG RUNS

    func loadDagRuns() async {

        isLoading = true

        defer {

            isLoading = false
        }

        do {

            let response = try await AirflowAPIService.shared.fetchDagRuns()

            dagRuns = response.sorted { first, second in

                let firstDate = first.startDate ?? ""

                let secondDate = second.startDate ?? ""

                return firstDate > secondDate
            }

            print("TOTAL DAG RUNS = \(dagRuns.count)")

            print("SUCCESS COUNT = \(successCount)")
            print("FAILED COUNT = \(failedCount)")
            print("RUNNING COUNT = \(runningCount)")

            // MARK: GRAPH DATA

            graphData = [

                ChartPoint(
                    day: "SUCCESS",
                    value: Double(successCount)
                ),

                ChartPoint(
                    day: "FAILED",
                    value: Double(failedCount)
                ),

                ChartPoint(
                    day: "RUNNING",
                    value: Double(runningCount)
                )
            ]

            print("GRAPH DATA = \(graphData)")

        } catch {

            errorMessage = error.localizedDescription

            print("LOAD DAG RUN ERROR = \(error)")
        }
    }

    // MARK: RUN DAG

    func runDAG(
        dagID: String
    ) async {

        do {

            try await AirflowAPIService.shared.triggerDAG(
                dagID: dagID
            )

            print("TRIGGER SUCCESS = \(dagID)")

            await loadDagRuns()

        } catch {

            errorMessage = error.localizedDescription

            print("RUN DAG ERROR = \(error)")
        }
    }
}
