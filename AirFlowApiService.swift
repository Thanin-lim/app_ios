//
//  AirFlowApiService.swift
//  warvba.thanin.test
//

import Foundation

// MARK: - ERROR

enum AirflowError: Error {

    case invalidURL

    case invalidResponse

    case httpError(code: Int)
}

// MARK: - API SERVICE

final class AirflowAPIService {

    static let shared = AirflowAPIService()

    private init() {}

    // MARK: CONFIG

    private var baseURL: String = "http://100.106.98.53:30007"

    private var username: String = "admin"

    private var password: String = "admin"

    // MARK: CONFIGURE

    func configure(
        host: String,
        username: String,
        password: String
    ) {

        self.baseURL = host

        self.username = username

        self.password = password
    }

    // MARK: HEADERS

    private var headers: [String: String] {

        let login = "\(username):\(password)"

        let data = login.data(using: .utf8) ?? Data()

        let base64 = data.base64EncodedString()

        return [

            "Authorization": "Basic \(base64)",

            "Content-Type": "application/json"
        ]
    }

    // MARK: FETCH DAGS

    func fetchDAGs() async throws -> [AirflowDAG] {

        guard let url = URL(
            string: "\(baseURL)/api/v1/dags"
        ) else {

            throw AirflowError.invalidURL
        }

        print("========== LOAD DAGS ==========")
        print("URL = \(url.absoluteString)")

        var request = URLRequest(url: url)

        request.httpMethod = "GET"

        headers.forEach {

            request.setValue(
                $1,
                forHTTPHeaderField: $0
            )
        }

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {

            throw AirflowError.invalidResponse
        }

        print("STATUS = \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {

            if let body = String(
                data: data,
                encoding: .utf8
            ) {

                print("ERROR BODY = \(body)")
            }

            throw AirflowError.httpError(
                code: httpResponse.statusCode
            )
        }

        let decoded = try JSONDecoder().decode(
            AirflowDAGResponse.self,
            from: data
        )

        print("TOTAL DAGS = \(decoded.dags.count)")

        for dag in decoded.dags {

            print("""
            DAG:
            id = \(dag.dagID)
            paused = \(dag.isPaused ?? false)
            """)
        }

        return decoded.dags
    }

    // MARK: FETCH DAG RUNS

    func fetchDagRuns() async throws -> [AirflowDagRun] {

        print("========== LOAD DAG RUNS ==========")

        // โหลด DAG ทั้งหมดก่อน

        let dags = try await fetchDAGs()

        var allRuns: [AirflowDagRun] = []

        // Loop ยิง API ทีละ DAG

        for dag in dags {

            guard let url = URL(
                string: "\(baseURL)/api/v1/dags/\(dag.dagID)/dagRuns"
            ) else {

                continue
            }

            print("LOAD RUNS URL = \(url.absoluteString)")

            var request = URLRequest(url: url)

            request.httpMethod = "GET"

            headers.forEach {

                request.setValue(
                    $1,
                    forHTTPHeaderField: $0
                )
            }

            do {

                let (data, response) = try await URLSession.shared.data(
                    for: request
                )

                guard let httpResponse = response as? HTTPURLResponse else {

                    continue
                }

                print("""
                DAG = \(dag.dagID)
                STATUS = \(httpResponse.statusCode)
                """)

                guard httpResponse.statusCode == 200 else {

                    if let body = String(
                        data: data,
                        encoding: .utf8
                    ) {

                        print("ERROR BODY = \(body)")
                    }

                    continue
                }

                let decoded = try JSONDecoder().decode(
                    AirflowDagRunResponse.self,
                    from: data
                )

                print("""
                DAG = \(dag.dagID)
                RUN COUNT = \(decoded.dagRuns.count)
                """)

                for run in decoded.dagRuns {

                    print("""
                    RUN:
                    dag = \(run.dagID)
                    run = \(run.dagRunID)
                    state = \(run.state)
                    """)
                }

                allRuns.append(
                    contentsOf: decoded.dagRuns
                )

            } catch {

                print("""
                LOAD DAG RUN FAILED
                DAG = \(dag.dagID)
                ERROR = \(error)
                """)
            }
        }

        print("TOTAL ALL RUNS = \(allRuns.count)")

        return allRuns
    }

    // MARK: TRIGGER DAG

    func triggerDAG(
        dagID: String
    ) async throws {

        guard let url = URL(
            string: "\(baseURL)/api/v1/dags/\(dagID)/dagRuns"
        ) else {

            throw AirflowError.invalidURL
        }

        print("========== TRIGGER DAG ==========")
        print("RUN DAG = \(dagID)")

        var request = URLRequest(url: url)

        request.httpMethod = "POST"

        headers.forEach {

            request.setValue(
                $1,
                forHTTPHeaderField: $0
            )
        }

        request.httpBody = try JSONSerialization.data(
            withJSONObject: [:]
        )

        let (_, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {

            throw AirflowError.invalidResponse
        }

        print("STATUS = \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 ||
                httpResponse.statusCode == 201 else {

            throw AirflowError.httpError(
                code: httpResponse.statusCode
            )
        }

        print("TRIGGER SUCCESS = \(dagID)")
    }
}
