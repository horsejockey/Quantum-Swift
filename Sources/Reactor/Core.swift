//
//  Core.swift
//  Reactor
//
//  Created by Matthew McArthur on 10/18/19.
//  Copyright © 2019 McArthur Labs. All rights reserved.
//

import Foundation
import PureStateMachine
import MessageRouter

public final class Core<State, Event, Command> {

    public typealias CommandProcessor = (Core<State, Event, Command>, Command) -> Void

    public let stateChanged = MessageRouter<State>()

    public var currentState: State {
        return stateMachine.currentState
    }

    private let stateMachine: PureStateMachine<State, Event, Command>
    private let commandProcessors: [CommandProcessor]

    public init(
        initialState: State,
        commandProcessors: [CommandProcessor] = [],
        eventHandler: @escaping PureStateMachine<State, Event, Command>.EventHandler
    ) {
        self.stateMachine = PureStateMachine<State, Event, Command>(
            initialState: initialState,
            label: "com.mcarthurlabs.Core",
            eventHandler: eventHandler
        )
        self.commandProcessors = commandProcessors
    }

    
    public func fire(event: Event) {
        DispatchQueue.global(qos: .default).async {
            let update = self.stateMachine.handleEvent(event)

            if let state = update.state {
                self.stateChanged.send(state)
            }

            for command in update.commands {
                for processor in self.commandProcessors {
                    processor(self, command)
                }
            }
        }
    }

    public func perform(command: Command) {
        DispatchQueue.global(qos: .default).async {
            self.commandProcessors.forEach { $0(self, command) }
        }
    }
}
