import Foundation

struct AirflowDAGResponse: Codable {
    let dags: [AirflowDAG]
}

struct AirflowDAG: Codable, Identifiable {

    let dagID: String
    let isPaused: Bool?
    let owners: [String]?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case dagID = "dag_id"
        case isPaused = "is_paused"
        case owners
        case description
    }

    var id: String {
        dagID
    }
}

struct AirflowDagRunResponse: Codable {

    let dagRuns: [AirflowDagRun]

    enum CodingKeys: String, CodingKey {
        case dagRuns = "dag_runs"
    }
}

struct AirflowDagRun: Codable, Identifiable {

    let dagRunID: String
    let dagID: String
    let state: String
    let startDate: String?
    let endDate: String?

    enum CodingKeys: String, CodingKey {

        case dagRunID = "dag_run_id"
        case dagID = "dag_id"
        case state
        case startDate = "start_date"
        case endDate = "end_date"
    }

    var id: String {
        dagRunID
    }
}
