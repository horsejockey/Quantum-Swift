import XCTest
import PureStateMachine
import Combine
@testable import Quantum

final class QuantumTests: XCTestCase {
    
    private enum Event {
        case update(Int)
    }
    
    private enum Command {
        case updateSoon(Int)
    }
    
    private func createCore(initialState: Int, processors: [Core<Int, Event, Command>.CommandProcessor]) -> Core<Int, Event, Command> {
        return Core(initialState: 0, commandProcessors: processors, eventHandler: QuantumTests.eventHandler)
    }
    
    private static func eventHandler(state: Int, event: Event) -> StateUpdate<Int, Command> {
        switch event {
        case .update(let value):
            return .State(value)
        }
    }
    
    private var disposables = Set<AnyCancellable>()
    
    func testStatePublisher() {
        let updateExpectation = expectation(description: "State update")
        updateExpectation.expectedFulfillmentCount = 2 // one for current state on subscribe one for after event is fired.
        let core = createCore(initialState: 0, processors: [])
        core.stateChanged.sink { state in
            updateExpectation.fulfill()
            XCTAssertEqual(0, state)
        }.store(in: &disposables)
        core.fire(event: .update(0))
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testCommandHandler() {
        let updateExpectation = expectation(description: "State update")
        let commandExpectation = expectation(description: "State update")
        updateExpectation.expectedFulfillmentCount = 2 // one for current state on subscribe one for after event is fired.
        let commandProcessor = { (core: Core<Int, Event, Command>, command: Command) -> Void in
            switch command {
            case .updateSoon(let value):
                DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .milliseconds(10)) {
                    core.fire(event: .update(value))
                }
            }
            commandExpectation.fulfill()
        }
        let core = createCore(initialState: 0, processors: [commandProcessor])
        core.stateChanged.sink { state in
            updateExpectation.fulfill()
            XCTAssertEqual(0, state)
        }.store(in: &disposables)
        core.perform(command: .updateSoon(0))
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testStateUpdates() {
        let updateExpectation = expectation(description: "State update")
        let count = 1000
        updateExpectation.expectedFulfillmentCount = count + 1 // one for current state on subscribe one for after event is fired.
        let core = createCore(initialState: 0, processors: [])
        var currentCount = 0
        core.stateChanged.sink { state in
            updateExpectation.fulfill()
            XCTAssertEqual(state, currentCount)
            currentCount += 1
        }.store(in: &disposables)
        for i in 1...count {
            core.fire(event: .update(i))
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    static var allTests = [
        ("testStatePublisher", testStatePublisher),
        ("testCommandHandler", testCommandHandler),
        ("testStateUpdates", testStateUpdates),
    ]
}
