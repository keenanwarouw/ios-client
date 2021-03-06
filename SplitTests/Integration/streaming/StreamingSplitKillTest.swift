//
//  StreamingSplitKillTest.swift
//  SplitTests
//
//  Created by Javier L. Avrudsky on 16/10/2020.
//  Copyright © 2020 Split. All rights reserved.
//

import XCTest
@testable import Split

class StreamingSplitKillTest: XCTestCase {
    var httpClient: HttpClient!
    let apiKey = IntegrationHelper.dummyApiKey
    let userKey = IntegrationHelper.dummyUserKey
    var streamingBinding: TestStreamResponseBinding?
    let sseConnExp = XCTestExpectation(description: "sseConnExp")
    var splitsChangesHits = 0
    var numbers = [500, 1000, 2000, 3000, 4000]
    var changes = [String]()
    var exps = [XCTestExpectation]()
    let kInitialChangeNumber = 1000
    var expIndex: Int = 0
    var queue = DispatchQueue(label: "hol", qos: .userInteractive)

    override func setUp() {
        expIndex = 1
        let session = HttpSessionMock()
        let reqManager = HttpRequestManagerTestDispatcher(dispatcher: buildTestDispatcher(),
                                                          streamingHandler: buildStreamingHandler())
        httpClient = DefaultHttpClient(session: session, requestManager: reqManager)
        loadChanges()
    }

    func testSplitKill() {
        let splitConfig: SplitClientConfig = SplitClientConfig()
        splitConfig.featuresRefreshRate = 9999
        splitConfig.segmentsRefreshRate = 9999
        splitConfig.impressionRefreshRate = 999999
        splitConfig.sdkReadyTimeOut = 60000
        splitConfig.eventsPushRate = 999999
        //splitConfig.isDebugModeEnabled = true

        let key: Key = Key(matchingKey: userKey)
        let builder = DefaultSplitFactoryBuilder()
        _ = builder.setHttpClient(httpClient)
        _ = builder.setReachabilityChecker(ReachabilityMock())
        let factory = builder.setApiKey(apiKey).setKey(key)
            .setConfig(splitConfig).build()!

        let client = factory.client
        let expTimeout:  TimeInterval = 100

        let sdkReadyExpectation = XCTestExpectation(description: "SDK READY Expectation")
        for i in 0..<4 {
            exps.insert(XCTestExpectation(description: "Exp changes \(i)"), at: i)
        }

        client.on(event: SplitEvent.sdkReady) {
            IntegrationHelper.tlog("READY")
            sdkReadyExpectation.fulfill()
        }

        client.on(event: SplitEvent.sdkReadyTimedOut) {
            IntegrationHelper.tlog("TIMEOUT")
        }

        wait(for: [sdkReadyExpectation, sseConnExp], timeout: expTimeout)
        
        IntegrationHelper.tlog("KEEPAL")
        streamingBinding?.push(message: ":keepalive") // send keep alive to confirm streaming connection ok
        wait(for: [curExp()], timeout: expTimeout)

        let splitName = "workm"
        let treatmentReady = client.getTreatment(splitName)

        streamingBinding?.push(message:
            StreamingIntegrationHelper.splitKillMessagge(splitName: splitName, defaultTreatment: "conta",
                                                         timestamp: numbers[splitsChangesHits],
                                                         changeNumber: numbers[splitsChangesHits]))

        wait(for: [curExp()], timeout: expTimeout)
        
        let treatmentKill = client.getTreatment(splitName)

        streamingBinding?.push(message:
            StreamingIntegrationHelper.splitUpdateMessage(timestamp: numbers[splitsChangesHits],
                                                          changeNumber: numbers[splitsChangesHits]))

        wait(for: [curExp()], timeout: expTimeout)
        let treatmentNoKill = client.getTreatment(splitName)
        
        streamingBinding?.push(message:
            StreamingIntegrationHelper.splitKillMessagge(splitName: splitName, defaultTreatment: "conta",
                                                         timestamp: numbers[0],
                                                         changeNumber: numbers[0]))

        ThreadUtils.delay(seconds: 2.0) // The server should not be hit here
        let treatmentOldKill = client.getTreatment(splitName)

        XCTAssertEqual("on", treatmentReady)
        XCTAssertEqual("conta", treatmentKill)
        XCTAssertEqual("on", treatmentNoKill)
        XCTAssertEqual("on", treatmentOldKill)
    }
    
    private func getChanges(for hitNumber: Int) -> Data {
        if hitNumber < exps.count {
            return Data(self.changes[hitNumber].utf8)
        }
        return Data(IntegrationHelper.emptySplitChanges(since: 999999, till: 999999).utf8)
    }

    private func buildTestDispatcher() -> HttpClientTestDispatcher {
        return { request in
            switch request.url.absoluteString {
            case let(urlString) where urlString.contains("splitChanges"):
                let hitNumber = self.getAndUpdateHit()
                IntegrationHelper.tlog("sc hit: \(hitNumber)")
                if hitNumber > 0, hitNumber < self.exps.count {
                    let exp = self.exps[hitNumber]
                    self.queue.asyncAfter(deadline: .now() + 0.5) {
                        IntegrationHelper.tlog("sc exp: \(hitNumber)")
                        exp.fulfill()
                    }
                }
                return TestDispatcherResponse(code: 200, data: self.getChanges(for: hitNumber))

            case let(urlString) where urlString.contains("mySegments"):
                return TestDispatcherResponse(code: 200, data: Data(IntegrationHelper.emptyMySegments.utf8))

            case let(urlString) where urlString.contains("auth"):
                return TestDispatcherResponse(code: 200, data: Data(IntegrationHelper.dummySseResponse().utf8))
            default:
                return TestDispatcherResponse(code: 500)
            }
        }
    }
    
    private func getAndUpdateHit() -> Int {
        var hitNumber = 0
        DispatchQueue.global().sync {
            hitNumber = self.splitsChangesHits
            self.splitsChangesHits+=1
        }
        return hitNumber
    }

    private func buildStreamingHandler() -> TestStreamResponseBindingHandler {
        return { request in
            self.streamingBinding = TestStreamResponseBinding.createFor(request: request, code: 200)
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                self.sseConnExp.fulfill()
            }
            return self.streamingBinding!
        }
    }

    private func getChanges(killed: Bool, since: Int, till: Int) -> String {
        let change = IntegrationHelper.getChanges(fileName: "simple_split_change")
        change?.since = Int64(since)
        change?.till = Int64(till)
        let split = change?.splits?[0]

        if killed {
            split?.killed = true
            split?.defaultTreatment = "conta"
        }
        return (try? Json.encodeToJson(change)) ?? ""
    }

    private func loadChanges() {
        for i in 0..<4 {
            let change = getChanges(killed: (i == 2),
                                    since: self.numbers[i],
                                    till: self.numbers[i])
            changes.insert(change, at: i)
        }
    }
    
    private func curExp() -> XCTestExpectation {
        var index = 0
        DispatchQueue.global().sync {
            index = self.expIndex
            self.expIndex+=1
        }
        return exps[index]
    }
}



