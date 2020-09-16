//
//  MySegmentsSyncWorkerTest.swift
//  SplitTests
//
//  Created by Javier L. Avrudsky on 16/09/2020.
//  Copyright © 2020 Split. All rights reserved.
//

import Foundation

import XCTest
@testable import Split

class MySegmentsSyncWorkerTest: XCTestCase {

    var mySegmentsFetcher: MySegmentsChangeFetcherStub!
    var mySegmentsCache: MySegmentsCacheStub!
    var eventsManager: SplitEventsManagerMock!
    var backoffCounter: ReconnectBackoffCounterStub!
    var mySegmentsSyncWorker: RetryableMySegmentsSyncWorker!

    override func setUp() {
        mySegmentsFetcher = MySegmentsChangeFetcherStub()
        mySegmentsCache = MySegmentsCacheStub()
        eventsManager = SplitEventsManagerMock()
        backoffCounter = ReconnectBackoffCounterStub()

        eventsManager.isSegmentsReadyFired = false

        mySegmentsSyncWorker = RetryableMySegmentsSyncWorker(
            matchingKey: "CUSTOMER_ID",
            mySegmentsChangeFetcher: mySegmentsFetcher,
            mySegmentsCache: mySegmentsCache,
            eventsManager: eventsManager,
            reconnectBackoffCounter: backoffCounter)
    }

    func testOneTimeFetchSuccess() {

        var resultIsSuccess = false
        let exp = XCTestExpectation(description: "exp")
        mySegmentsSyncWorker.completion = { success in
            resultIsSuccess = success
            exp.fulfill()
        }
        mySegmentsSyncWorker.start()

        wait(for: [exp], timeout: 3)

        XCTAssertTrue(resultIsSuccess)
        XCTAssertEqual(0, backoffCounter.retryCallCount)
        XCTAssertTrue(eventsManager.isSegmentsReadyFired)
    }

    func testRetryAndSuccess() {

        mySegmentsFetcher.allSegments = [nil, nil, ["s1", "s2"]]
        var resultIsSuccess = false
        let exp = XCTestExpectation(description: "exp")
        mySegmentsSyncWorker.completion = { success in
            resultIsSuccess = success
            exp.fulfill()
        }
        mySegmentsSyncWorker.start()

        wait(for: [exp], timeout: 3)

        XCTAssertTrue(resultIsSuccess)
        XCTAssertEqual(2, backoffCounter.retryCallCount)
        XCTAssertTrue(eventsManager.isSegmentsReadyFired)
    }

    func testStopNoSuccess() {

        mySegmentsFetcher.allSegments = [nil]
        var resultIsSuccess = false
        let exp = XCTestExpectation(description: "exp")
        mySegmentsSyncWorker.completion = { success in
            resultIsSuccess = success
            exp.fulfill()
        }
        mySegmentsSyncWorker.start()
        sleep(1)
        mySegmentsSyncWorker.stop()

        wait(for: [exp], timeout: 3)

        XCTAssertFalse(resultIsSuccess)
        XCTAssertTrue(1 < backoffCounter.retryCallCount)
        XCTAssertFalse(eventsManager.isSegmentsReadyFired)
    }

    override func tearDown() {
    }
}
