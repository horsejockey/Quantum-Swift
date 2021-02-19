[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

# Quantum

Quantum is a framework based on [Reactor](https://github.com/ReactorSwift/Reactor/blob/master/README.md). They are both inspired by [Elm](https://github.com/evancz/elm-architecture-tutorial) and [Redux](http://redux.js.org/docs/basics/index.html) and there are several other similar projects for Swift based on these patterns.

[ReSwift](https://github.com/ReSwift/ReSwift)
[Swift Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)
[Loop](https://github.com/ReactiveCocoa/Loop)

And many more.

This iteration of the framework was originally created by [Rob Brown](https://github.com/rob-brown) [here](https://gist.github.com/rob-brown/0725f6609accd6348f2dc5bc883b1cd1) and is based on his [PureStateMachine](https://github.com/horsejockey/PureStateMachine-Swift). 

The idea behind all of these frameworks is to have single source of truth for you application state that can only be mutated by pre-defined events or actions you can take against the current state. Quantum achieves this by adding a light wrapper around a state machine to formalize and extend some of it's functionality.

## Architecture

```
+---------------------------+
|                           |
|           Core            |
|                           |       +---------+
|                           |  +----+  Event  +------+
|                           |  |    +---------+
|                           +<-+
|                           |
|     +---------------+     +---+   +---------+
|     |               |     |   +---+  State  +------>
|     | State Machine |     |       +---------+
|     |               |     |
|     +---------------+     |
|                           |
|                           |
|                           |
|   +-------------------+   |       +-----------+
|   |                   |   +<------+  Command  +------+
|   |  Command Handlers |   |       +-----------+
|   |                   |   |
|   +-------------------+   |
|                           |
+---------------------------+


```

There are six objects in the Reactor architecture:

1. The `State` object - A struct with properties representing application data.
1. The `Event` - Can trigger a state update.
1. The `Core` - Holds the application state and responsible for firing events.
1. The `Subscriber` - Often a view controller, listens for state updates.
1. The `Command` - A task that can asynchronously fire events. Useful for networking, working with databases, or any other asynchronous task.

## State

State can be anything but it should be immutable from outside the Core. Here is an example:

```swift
struct Player {
    var name: String
    var level: Int
}
```

and here is an example event and event handler.

```swift
enum PlayerEvent {
	case levelUp
}

static func eventHandler(state: Player, event: PlayerEvent) -> StateUpdate<Player, Command> {
    switch event {
    	case .levelUp:
    		var updatedState = state
    		updatedState.level += 1
    		return StateUpdate.state(updatedState)
    }
}
```

Here we have a simple `Player` model, which is state in our application. Obviously most application states are more complicated than this, but this is where composition comes into play: we can create state by composing states.

```swift
struct RPGState {
    var player: Player
    var monsters: Monsters
}

enum RPGEvent {
	case playerEvent(PlayerEvent)
	case monsterEvent(MonsterEvent)
}

```

Parent states can react to events however they wish, although this will in most cases involve delegating to substates.

```swift
static func eventHandler(state: RPGState, event: RPGEvent) -> StateUpdate<RPGState, Command> {
    switch event {
    	case .playerEvent(let playerEvent):
    		return Player.handleEvent(state: state.player, event: playerEvent)
                .mapState { playerState in
                    var updatedState = state
                    updatedState.player = playerState
                    return updatedState
                }
        case .monsterEvent(let monsterEvent):
    		// etc.
    }
}
```

## Events

We've seen that an `Event` can change state. What does an `Event` look like? In it's most basic form, an event might look like this:

```swift
enum PlayerEvent {
	case levelUp
}
```

You could also turn Event into a protocol and use structs

```swift
protocol Event {}

struct LevelUp: Event {}
```

## The Core

So, how does the state get events? Since the `Core` is responsible for all `State` changes, you can send events to the core which will in turn update the state by calling the event handler for your state machine. 

In order to initialize your core, simply call the `Core`'s constructor and pass in your initial state and any command handlers (discussed later in this readme).

```swift
public typealias CommandProcessor = (Core<State, Event, Command>, Command) -> Void

private static func createCore(
    initialState: App.State,
    processors: [CommandProcessor])
-> Core<App.State, App.Event, App.Command> {
    return Core(initialState: initialState, commandProcessors: processors, eventHandler: handleEvent)
}
```

Here is an example of a simple view controller with a label displaying our intrepid character's level, and a "Level Up" button.

```swift
class PlayerViewController: UIViewController {
    var core = App.sharedCore
    @IBOutlet weak var levelLabel: UILabel!

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        core.add(subscriber: self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        core.remove(subscriber: self)
    }

    @IBAction func didPressLevelUp() {
        core.fire(event: LevelUp())
    }
}

extension ViewController: Reactor.Subscriber {
    func update(with state: RPGState) {
        levelLabel?.text = String(state.level)
    }
}
```

By subscribing and subscribing in `viewDidAppear`/`viewDidDisappear` respectively, we ensure that whenever this view controller is visible it is up to date with the latest application state. Upon initial subscription, the core will send the latest state to the subscriber's `update` function. Button presses forward events back to the core, which will then update the state and result in subsequent calls to `update`. (note: the `Core` always dispatches back to the main thread when it updates subscribers, so it is safe to perform UI updates in `update`.)

## Commands

Sometimes a state change might also lead to side effects or perhaps you have an event that may lead to a state change in the future. Fort this we use the `Command` and corresponding command handlers help you interact with the `Core` in a safe and consistent way. 

Example of side affect that you may want carried out after a specific state change. Here we can see an event handler for some user session state. We can see here that after a user signs in two side effects happen. One is we will update the root route for the applications navigation and a second is a user session command to set the authentication token. The `UserSessionCommandHandler` will respond to the commands to either set the auth token or clear it on the `AuthorizedRequestController`

```swift
static func handleEvent(
    state: UserSessionState,
    event: UserSessionEvent
) -> StateUpdate<UserSessionState, App.Command> {
    switch event {
    case let .userSignedIn(email, token):
        return .StateAndCommands(
            .authenticated(email: email),
            [
                .sessionCommand(.userAuthenticated(token)),
                .navCommand(.replaceRootRoute(App.checkUserSessionRoute()))
            ]
        )

    case .signOut:
        return .StateAndCommands(
            .unauthenticated,
            [
                .sessionCommand(.clearUserAuth),
                .navCommand(.replaceRootRoute(App.loginRoute()))
            ]
        )
    }
}

final class UserSessionCommandHandler {

    static func commandProcessor(authController: AuthorizedRequestController) -> App.CommandProcessor {
        return { _, cmd in
            guard case let .sessionCommand(command) = cmd else { return }
            switch command {
            case .userAuthenticated(let token):
                authController.setAuthToken(authToken: token)

            case .clearUserAuth:
                authController.clearAuthToken()
            }
        }
    }
}

enum SessionCommand {
    case userAuthenticated(AuthToken)
    case clearUserAuth
}
```

Commands get a copy of the current state, and a reference to the Core which allows them to fire Events as necessary. Here we can see an example of a `Command` that may have a future affect on the application state. This command can be called directly on the `Core` by calling `core.perform(DataCommand.getFolders)`.

```swift
final class AppDataController {

    static func commandProcessor(appRepo: AppRepo) -> App.CommandProcessor {

        return { core, cmd in
            guard case let .dataCommand(command) = cmd else { return }
            switch command {
            case .getFolders:
                appRepo.getFolders() { result in
                    switch result {
                    case .success(let folders):
                        core.fire(event: .userDataEvent(.foldersFound(folders)))
                    case .failure(let error):
                        Logger.error(tag: .reactorCommand, message: "\(error)")
                    }
                }
            }
        }
    }
}

enum DataCommand {
    case getFolders
}

```

We can even use a `Command` to handle things like optimistic app state updates. Here we pre-emptively remove the folder from the application state by firing and event: `core.fire(event: .userDataEvent(.removeFolder(objectID)))` and if the network request succeeds nothing more needs to happen. If it fails then we can re-upsert the folder into the application state and do some error handling for the user.

```swift
final class AppDataController {

    static func commandProcessor(appRepo: AppRepo) -> App.CommandProcessor {

        return { core, cmd in
            guard case let .dataCommand(command) = cmd else { return }
            switch command {

            case .closeFolder(let objectID):
                guard let originalFolder = core.currentState.folders.first(where: { $0.objectID == objectID }) else {
                    return
                }
                // Make an optimistic update.
                core.fire(event: .userDataEvent(.removeFolder(objectID)))
                appRepo.closeFolder(objectID: objectID) { result in
                    switch result {
                    case .success:
                        break // Do nothing. We already made an optimistic update.
                    case .failure(let error):
                        // Undo optimistic update
                        core.fire(event: .userDataEvent(.upsertFolder(originalFolder)))
                        core.perform(
                            command: .navCommand(
                                .alert(
                                    AlertInfo(
                                        title: "An error occurreed",
                                        message: "We were unable to remove the folder at this time.",
                                        primaryAction: AlertAction(
                                            text: "Ok",
                                            style: .default
                                        )
                                    )
                                )
                            )
                        )
                        Logger.error(tag: .reactorCommand, message: "\(error)")
                    }
                }
            }
        }
    }
}

enum DataCommand {
    case closeFolder(objectID: String)
}
```
