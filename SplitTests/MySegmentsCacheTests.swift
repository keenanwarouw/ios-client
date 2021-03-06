//
//  MySegmentsCacheTests.swift
//  SplitTests
//
//  Created by Javier L. Avrudsky on 29/11/2018.
//  Copyright © 2018 Split. All rights reserved.
//

import XCTest

@testable import Split

class MySegmentsCacheTests: XCTestCase {
    
    var mySegmentsCache: MySegmentsCacheProtocol!

    override func setUp() {
        let fileContent = "{\"matchingKey\": \"fake_id_1\", \"segments\": [\"segment0\", \"segment1\", \"segment2\"]}"
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let filePrefix = "SPLITIO.mySegments"
        let matchingKey = "fake_id_1"
        let fileStorage = FileStorageStub()
        fileStorage.write(fileName: "\(filePrefix)_\(matchingKey)", content: fileContent)
        mySegmentsCache = MySegmentsCache(matchingKey: "fake_id_1", fileStorage: fileStorage)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    func testInitialSegments(){
        XCTAssertEqual(mySegmentsCache.getSegments().count, 3, "Initial segments count check")
        XCTAssertTrue(mySegmentsCache.isInSegments(name: "segment0"), "Initial segments - segment0 should be in cache")
        XCTAssertTrue(mySegmentsCache.isInSegments(name: "segment1"), "Initial segments - segment1 should be in cache")
        XCTAssertTrue(mySegmentsCache.isInSegments(name: "segment2"), "Initial segments - segment2 should be in cache")
    }
    
    func testAddOneSegment() {
        mySegmentsCache.setSegments(["segments0", "segments1", "segments2", "segment3"])
        XCTAssertEqual(mySegmentsCache.getSegments().count, 4, "Added 1 segments - count")
        XCTAssertTrue(mySegmentsCache.isInSegments(name: "segment3"), "segment3 should be in cache")
    }
    
    func testAddTwoSegments() {
        mySegmentsCache.setSegments(["segments0", "segments1", "segments2", "segment3", "segment4", "segment5"])
        XCTAssertEqual(mySegmentsCache.getSegments().count, 6, "Added 1 segments - count")
        XCTAssertTrue(mySegmentsCache.isInSegments(name: "segment4"), "segment4 should be in cache")
        XCTAssertTrue(mySegmentsCache.isInSegments(name: "segment5"), "segment5 should be in cache")
    }
    
    func testRemoveOneSegment() {
        mySegmentsCache.setSegments(["segment0", "segment1"])
        XCTAssertEqual(mySegmentsCache.getSegments().count, 2, "Removed 1 segment - count")
        XCTAssertTrue(mySegmentsCache.isInSegments(name: "segment0"), "segment0 should be in cache")
        XCTAssertTrue(mySegmentsCache.isInSegments(name: "segment1"), "segment1 should be in cache")
        XCTAssertFalse(mySegmentsCache.isInSegments(name: "segment2"), "segment2 should not be in cache")
    }
    
    func testRemoveTwoSegments() {
        mySegmentsCache.setSegments(["segment1"])
        XCTAssertEqual(mySegmentsCache.getSegments().count, 1, "Removed 2 segments - count")
        XCTAssertFalse(mySegmentsCache.isInSegments(name: "segment0"), "segment0 should not be in cache")
        XCTAssertTrue(mySegmentsCache.isInSegments(name: "segment1"), "segment1 should be in cache")
        XCTAssertFalse(mySegmentsCache.isInSegments(name: "segment2"), "segment2 should not be in cache")
    }
    
    func testRemoveAllSegments() {
        mySegmentsCache.removeSegments()
        XCTAssertEqual(mySegmentsCache.getSegments().count, 0, "Removed all segments - count")
        XCTAssertFalse(mySegmentsCache.isInSegments(name: "segment0"), "segment0 should not be in cache")
        XCTAssertFalse(mySegmentsCache.isInSegments(name: "segment1"), "segment1 should not be in cache")
        XCTAssertFalse(mySegmentsCache.isInSegments(name: "segment2"), "segment2 should not be in cache")
    }
    

}
