module Gamepad
    exposing
        ( Blob
        , RawGamepad
          -- database
        , Database
        , emptyDatabase
        , databaseToString
        , databaseFromString
          -- unknown gamepads
        , UnknownGamepad
        , getUnknownGamepads
        , unknownGetId
        , unknownGetIndex
          -- known gamepads
        , Gamepad
        , getGamepads
        , getIndex
        , aIsPressed
        , bIsPressed
        , xIsPressed
        , yIsPressed
        , startIsPressed
        , backIsPressed
        , homeIsPressed
        , dpadUpIsPressed
        , dpadDownIsPressed
        , dpadLeftIsPressed
        , dpadRightIsPressed
        , dpadX
        , dpadY
        , leftX
        , leftY
        , leftStickIsPressed
        , leftBumperIsPressed
        , leftTriggerIsPressed
        , leftTriggerValue
        , rightX
        , rightY
        , rightStickIsPressed
        , rightBumperIsPressed
        , rightTriggerIsPressed
        , rightTriggerValue
          -- mapping
        , Origin
        , Destination(..)
        , estimateOrigin
        , buttonMapToUpdateDatabase
        , getAllGamepadsAsUnknown
        )

{-| A library to make sense of
[navigator.getGamepads()](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/getGamepads)

First things first: you need a JavaScript port to get the return value of
`navigator.getGamepads()` inside Elm.
You can copy the port files from [port/](https://github.com/xarvh/elm-gamepad/tree/master/port).

Within the library, the raw gamepad information produced by the port is called [Blob](#Blob).

You can get a list of all recognised and connected gamepads with [getGamepads](#getGamepads).

To access the information of each [Gamepad](#Gamepad), you can use the button
getters: [aIsPressed](#aIsPressed), [leftX](#leftX),
[rightTriggerValue](#rightTriggerValue) and so on...

Many gamepads have [a standard mapping](https://www.w3.org/TR/gamepad/#remapping)
and will be recognised automatically, but for all other gamepads, or for custom
mappings, you will need a button maps [Database](#Database):
you can default to [emptyDatabase](#emptyDatabase), and include a remapping
tool in your app to allow the user to create the mapping.

You can use the bare-bones remapping tool provided in
[Gamepad.Remap](#Gamepad-Remap) or [build your own](#mapping);
[getUnknownGamepads](#getUnknownGamepads) will give you a list of connected
gamepads that need to be mapped.


# Blob

@docs Blob


# Database

@docs Database, emptyDatabase, databaseFromString, databaseToString


# Unknown Gamepads

@docs UnknownGamepad, getUnknownGamepads, unknownGetId, unknownGetIndex


# Gamepads

Depending on the hardware, the drivers and the browser, some input values
will be digital (True or False) and some will be analog (0 to 1 or -1 to 1).

The library hides this complexity and converts the values as necessary.

@docs Gamepad, getGamepads, getIndex


### Face buttons

@docs aIsPressed, bIsPressed, xIsPressed, yIsPressed


### Utility buttons

@docs startIsPressed, backIsPressed, homeIsPressed


### Directional pad

@docs dpadUpIsPressed, dpadDownIsPressed, dpadLeftIsPressed, dpadRightIsPressed, dpadX, dpadY


### Left thumbstick

@docs leftX, leftY, leftStickIsPressed, leftBumperIsPressed, leftTriggerIsPressed, leftTriggerValue


### Right thumbstick

@docs rightX, rightY, rightStickIsPressed, rightBumperIsPressed, rightTriggerIsPressed, rightTriggerValue


# Mapping

These are the functions used to write the remapping tool in [Gamepad.Remap](#Gamepad-Remap).
You need them only if instead of [Gamepad.Remap](#Gamepad-Remap) you want to
write your own remapping tool.

A button map associates a raw gamepad input, the [Origin](#Origin), with a
button name, the [Destination](#Destination).

The steps to create a button map are roughly:

1.  For every [Destination](#Destination) your application requires, you should:
      - Ask the user to press/push it.
      - Use [estimateOrigin](#estimateOrigin) to know which [Origin](#Origin) is being activated.
      - Store this [Origin](#Origin) in a tuple together with its [Destination](#Destination).
2.  Pass the list of `(Destination, Origin)` tuples to [buttonMapToUpdateDatabase](#buttonMapToUpdateDatabase)
    to add the new mapping to your [Database](#Database).

@docs getAllGamepadsAsUnknown, Origin, Destination, estimateOrigin, buttonMapToUpdateDatabase


# Test

@docs RawGamepad

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Regex
import Set exposing (Set)
import Time exposing (Time)


{-| A recognised gamepad, whose buttons mapping was found in the Database.
You can use all control getters to query its state.
-}
type Gamepad
    = Gamepad String RawGamepad


{-| A gamepad that was not found in the Database.
Because of the sheer diversity of gamepads in the wild, there isn't much that
you can reliably do with it.

However, you can remap it and add its entry to the database, so that next time
it will be recognised!

-}
type UnknownGamepad
    = UnknownGamepad RawGamepad


{-| A collection of button maps, by gamepad Id.

If you change the mapping for one gamepad, the mapping will change for all the
gamepads of that type (ie, all the gamepads that share that Id).

-}
type Database
    = Database (Dict String ButtonMap)


{-| An Origin references an input in the javascript [gamepad](https://w3c.github.io/gamepad/)
object.
-}
type Origin
    = Origin Bool OriginType Int


type OriginType
    = Axis
    | Button


type alias ButtonMap =
    String


{-| A Blob describes the raw return value of `navigator.getGamepads()`.

The whole point of this library is to transform the Blob into something
that is nice to use with Elm.

-}
type alias Blob =
    List (Maybe RawGamepad)


{-| This type is exposed only for testing purposes. Don't use it.
-}
type alias RawGamepad =
    { axes : Array Float
    , buttons : Array ( Bool, Float )
    , connected : Bool
    , id : String
    , index : Int
    , mapping : String
    , timestamp : Float
    }


{-| A Destination is just a way to reference a gamepad input that is understandable for the user.
-}
type Destination
    = A
    | B
    | X
    | Y
    | Start
    | Back
    | Home
    | LeftLeft
    | LeftRight
    | LeftUp
    | LeftDown
    | LeftStick
    | LeftBumper
    | LeftTrigger
    | RightLeft
    | RightRight
    | RightUp
    | RightDown
    | RightStick
    | RightBumper
    | RightTrigger
    | DpadUp
    | DpadDown
    | DpadLeft
    | DpadRight


destinationToString : Destination -> String
destinationToString destination =
    case destination of
        A ->
            "a"

        B ->
            "b"

        X ->
            "x"

        Y ->
            "y"

        Start ->
            "start"

        Back ->
            "back"

        Home ->
            "home"

        LeftLeft ->
            "leftleft"

        LeftRight ->
            "leftright"

        LeftUp ->
            "leftup"

        LeftDown ->
            "leftdown"

        LeftStick ->
            "leftstick"

        LeftBumper ->
            "leftbumper"

        LeftTrigger ->
            "lefttrigger"

        RightLeft ->
            "rightleft"

        RightRight ->
            "rightright"

        RightUp ->
            "rightup"

        RightDown ->
            "rightdown"

        RightStick ->
            "rightstick"

        RightBumper ->
            "rightbumper"

        RightTrigger ->
            "righttrigger"

        DpadUp ->
            "dpadup"

        DpadDown ->
            "dpaddown"

        DpadLeft ->
            "dpadleft"

        DpadRight ->
            "dpadright"



-- Adding a button map to a Database


intToString : Int -> String
intToString =
    toString


{-| If leftUp and leftDown point to different origins, then the normal

    leftY =
        leftUp - leftDown

is perfectly valid.

However if they are on the same origin and that origin is a -1 to +1 axis, the
equality above will yield values between -2 and +2.

This function detects such cases and removes one of the two origins from the
map.

    leftY =
        leftUp

-}
fixAxisCoupling : ( Destination, Destination ) -> Dict String Origin -> Dict String Origin
fixAxisCoupling ( destination1, destination2 ) map =
    case ( Dict.get (destinationToString destination1) map, Dict.get (destinationToString destination2) map ) of
        ( Just (Origin isReverse1 Axis index1), Just (Origin isReverse2 Axis index2) ) ->
            if index1 == index2 then
                Dict.remove (destinationToString destination1) map
            else
                map

        ( _, _ ) ->
            map


fixAllAxesCoupling : List ( String, Origin ) -> List ( String, Origin )
fixAllAxesCoupling map =
    [ ( LeftLeft, LeftRight )
    , ( LeftUp, LeftDown )
    , ( RightLeft, RightRight )
    , ( RightUp, RightDown )
    ]
        |> List.foldr fixAxisCoupling (Dict.fromList map)
        |> Dict.toList


buttonMap : List ( Destination, Origin ) -> ButtonMap
buttonMap map =
    let
        hasMinus isReverse =
            if isReverse then
                "-"
            else
                ""

        typeToString originType =
            case originType of
                Axis ->
                    "a"

                Button ->
                    "b"

        originToCode (Origin isReverse originType index) =
            hasMinus isReverse ++ typeToString originType ++ intToString index

        tupleDestinationToString ( destination, origin ) =
            ( destinationToString destination, origin )

        tupleToString ( destinationAsString, origin ) =
            destinationAsString ++ ":" ++ originToCode origin
    in
        map
            |> List.map tupleDestinationToString
            |> fixAllAxesCoupling
            |> List.map tupleToString
            |> List.sortBy identity
            |> String.join ","


{-| The function inserts a button map for a given gamepad Id in a [Database](#Database),
replacing any previous mapping for that gamepad Id.

The first argument is the gamepad the map is for.

The second argument is the map itself: a List of [Destination](#Destination)s vs
[Origin](#Origin)s.

The third argument is the [Database](#Database) to update.

-}
buttonMapToUpdateDatabase : UnknownGamepad -> List ( Destination, Origin ) -> Database -> Database
buttonMapToUpdateDatabase unknownGamepad map (Database database) =
    Dict.insert (unknownGetId unknownGamepad) (buttonMap map) database |> Database



-- Encoding and decoding Databases


{-| An empty Database.
-}
emptyDatabase : Database
emptyDatabase =
    Database Dict.empty


buttonMapDivider : String
buttonMapDivider =
    ",,,"


{-| Encodes a Database into a String, useful to persist the Database.

    saveDatabaseToLocalStorageCmd =
        gamepadDatabase
            |> databaseToString
            |> LocalStoragePort.set model.gamepadDatabaseKey

-}
databaseToString : Database -> String
databaseToString (Database database) =
    let
        tupleToString ( gamepadId, map ) =
            gamepadId ++ buttonMapDivider ++ map ++ "\n"
    in
        database
            |> Dict.toList
            |> List.map tupleToString
            |> List.sortBy identity
            |> String.join ""


{-| Decodes a Database from a String, useful to load a persisted Database.

    gamepadDatabase =
        flags.gamepadDatabaseAsString
            |> Gamepad.databaseFromString
            |> Result.withDefault Gamepad.emptyDatabase

-}
databaseFromString : String -> Result String Database
databaseFromString databaseAsString =
    let
        stringToTuple dbEntry =
            case String.split buttonMapDivider dbEntry of
                [ id, map ] ->
                    Just ( id, map )

                _ ->
                    Nothing
    in
        databaseAsString
            |> String.split "\n"
            |> List.map stringToTuple
            |> List.filterMap identity
            |> Dict.fromList
            |> Database
            -- TODO: detect and return errors instead of ignoring them silently
            |> Ok



-- Standard button maps


standardButtonMaps : Dict String ButtonMap
standardButtonMaps =
    [ ( "standard"
      , buttonMap
            -- https://www.w3.org/TR/gamepad/#remapping
            [ ( A, Origin False Button 0 )
            , ( B, Origin False Button 1 )
            , ( X, Origin False Button 2 )
            , ( Y, Origin False Button 3 )
            , ( Start, Origin False Button 9 )
            , ( Back, Origin False Button 8 )
            , ( Home, Origin False Button 16 )
            , ( LeftRight, Origin False Axis 0 )
            , ( LeftDown, Origin False Axis 1 )
            , ( LeftStick, Origin False Button 10 )
            , ( LeftBumper, Origin False Button 4 )
            , ( LeftTrigger, Origin False Button 6 )
            , ( RightRight, Origin False Axis 2 )
            , ( RightDown, Origin False Axis 3 )
            , ( RightStick, Origin False Button 11 )
            , ( RightBumper, Origin False Button 5 )
            , ( RightTrigger, Origin False Button 7 )
            , ( DpadUp, Origin False Button 12 )
            , ( DpadDown, Origin False Button 13 )
            , ( DpadLeft, Origin False Button 14 )
            , ( DpadRight, Origin False Button 15 )
            ]
      )
    ]
        |> Dict.fromList



-- Get gamepads


isConnected : RawGamepad -> Bool
isConnected rawGamepad =
    -- All browsers running under Windows 10 will sometimes throw in a zombie gamepad
    -- object, unrelated to any physical gamepad and never updated.
    -- Since this gamepad has always timestamp == 0, we use this to discard it.
    rawGamepad.connected && rawGamepad.timestamp > 0


getRawGamepads : Blob -> List RawGamepad
getRawGamepads blob =
    blob
        |> List.filterMap identity
        |> List.filter isConnected


getGamepadButtonMap : Database -> RawGamepad -> Maybe ButtonMap
getGamepadButtonMap (Database database) rawGamepad =
    case Dict.get rawGamepad.id database of
        Just buttonMap ->
            Just buttonMap

        Nothing ->
            Dict.get rawGamepad.mapping standardButtonMaps


getKnownAndUnknownGamepads : Database -> Blob -> ( List Gamepad, List UnknownGamepad )
getKnownAndUnknownGamepads database blob =
    let
        foldRawGamepad rawGamepad ( known, unknown ) =
            case getGamepadButtonMap database rawGamepad of
                Nothing ->
                    ( known
                    , UnknownGamepad rawGamepad :: unknown
                    )

                Just buttonMap ->
                    -- TODO: it might be faster to parse the button maps here, rather than running a regex at every getter
                    ( Gamepad buttonMap rawGamepad :: known
                    , unknown
                    )
    in
        blob
            |> getRawGamepads
            |> List.foldr foldRawGamepad ( [], [] )


{-| Get a List of all recognised Gamepads (ie, those that can be found in the Database).
-}
getGamepads : Database -> Blob -> List Gamepad
getGamepads database blob =
    getKnownAndUnknownGamepads database blob |> Tuple.first


{-| Get a List of all gamepads that do not have a mapping.
If there are any, you need to run the remapping tool to create a Database
entry for them, otherwise the user won't be able to use them.
-}
getUnknownGamepads : Database -> Blob -> List UnknownGamepad
getUnknownGamepads database blob =
    getKnownAndUnknownGamepads database blob |> Tuple.second


{-| Get a List of all connected gamepads, whether they are recognised or not.
-}
getAllGamepadsAsUnknown : Blob -> List UnknownGamepad
getAllGamepadsAsUnknown blob =
    getRawGamepads blob |> List.map UnknownGamepad



-- input code helpers


stringToInputType : String -> Maybe OriginType
stringToInputType s =
    case s of
        "a" ->
            Just Axis

        "b" ->
            Just Button

        _ ->
            Nothing


maybeToReverse : Maybe String -> Bool
maybeToReverse maybeReverse =
    case maybeReverse of
        Just "-" ->
            True

        _ ->
            False


regexMatchToInputTuple : Regex.Match -> Maybe ( OriginType, Int, Bool )
regexMatchToInputTuple match =
    case match.submatches of
        _ :: maybeReverse :: (Just inputTypeAsString) :: (Just indexAsString) :: _ ->
            Maybe.map3 (,,)
                (inputTypeAsString |> stringToInputType)
                (indexAsString |> String.toInt |> Result.toMaybe)
                (maybeReverse |> maybeToReverse |> Just)

        _ ->
            Nothing


mappingToRawIndex : Destination -> String -> Maybe ( OriginType, Int, Bool )
mappingToRawIndex destination mapping =
    let
        regex =
            "(^|,)" ++ destinationToString destination ++ ":(-)?([a-z]?)([0-9]+)(,|$)"
    in
        mapping
            |> Regex.find (Regex.AtMost 1) (Regex.regex regex)
            |> List.head
            |> Maybe.andThen regexMatchToInputTuple


axisToButton : Float -> Bool
axisToButton n =
    n > 0.1


buttonToAxis : Bool -> Float
buttonToAxis b =
    if b then
        1
    else
        0


reverseAxis : Bool -> Float -> Float
reverseAxis isReverse n =
    if isReverse then
        -n
    else
        n


isPressed : Destination -> Gamepad -> Bool
isPressed destination (Gamepad mapping rawGamepad) =
    case mappingToRawIndex destination mapping of
        Nothing ->
            False

        Just ( Axis, index, isReverse ) ->
            Array.get index rawGamepad.axes
                |> Maybe.withDefault 0
                |> reverseAxis isReverse
                |> axisToButton

        Just ( Button, index, isReverse ) ->
            Array.get index rawGamepad.buttons
                |> Maybe.map Tuple.first
                |> Maybe.withDefault False


getValue : Destination -> Gamepad -> Float
getValue destination (Gamepad mapping rawGamepad) =
    case mappingToRawIndex destination mapping of
        Nothing ->
            0

        Just ( Axis, index, isReverse ) ->
            Array.get index rawGamepad.axes
                |> Maybe.withDefault 0
                |> reverseAxis isReverse

        Just ( Button, index, isReverse ) ->
            Array.get index rawGamepad.buttons
                |> Maybe.map Tuple.second
                |> Maybe.withDefault 0


getAxis : Destination -> Destination -> Gamepad -> Float
getAxis negativeDestination positiveDestination pad =
    (getValue positiveDestination pad - getValue negativeDestination pad)
        |> clamp -1 1



-- Unknown Gamepad getters


{-| Get the identifier String of an unknown gamepad, as provided by the browser

    unknownGetId unknownGamepad == "Microsoft Corporation. Controller (STANDARD GAMEPAD Vendor: 045e Product: 028e)"

-}
unknownGetId : UnknownGamepad -> String
unknownGetId (UnknownGamepad raw) =
    raw.id


{-| Get the index of an unknown gamepad.
Indexes start from 0.

    unknownGetIndex unknownGamepad == 0

-}
unknownGetIndex : UnknownGamepad -> Int
unknownGetIndex (UnknownGamepad raw) =
    raw.index



-- Gamepad getters


{-| Get the index of a known gamepad.
Indexes start from 0.

    getIndex gamepad == 2

-}
getIndex : Gamepad -> Int
getIndex (Gamepad string raw) =
    raw.index


{-| -}
aIsPressed : Gamepad -> Bool
aIsPressed =
    isPressed A


{-| -}
bIsPressed : Gamepad -> Bool
bIsPressed =
    isPressed B


{-| -}
xIsPressed : Gamepad -> Bool
xIsPressed =
    isPressed X


{-| -}
yIsPressed : Gamepad -> Bool
yIsPressed =
    isPressed Y



-- utility


{-| -}
startIsPressed : Gamepad -> Bool
startIsPressed =
    isPressed Start


{-| -}
backIsPressed : Gamepad -> Bool
backIsPressed =
    isPressed Back


{-| -}
homeIsPressed : Gamepad -> Bool
homeIsPressed =
    isPressed Home



-- dpad


{-| -}
dpadUpIsPressed : Gamepad -> Bool
dpadUpIsPressed =
    isPressed DpadUp


{-| -}
dpadDownIsPressed : Gamepad -> Bool
dpadDownIsPressed =
    isPressed DpadDown


{-| -}
dpadLeftIsPressed : Gamepad -> Bool
dpadLeftIsPressed =
    isPressed DpadLeft


{-| -}
dpadRightIsPressed : Gamepad -> Bool
dpadRightIsPressed =
    isPressed DpadRight


{-| -1 means left, 0 means center, 1 means right
-}
dpadX : Gamepad -> Int
dpadX pad =
    if dpadLeftIsPressed pad then
        -1
    else if dpadRightIsPressed pad then
        1
    else
        0


{-| -1 means down, 0 means center, 1 means up
-}
dpadY : Gamepad -> Int
dpadY pad =
    if dpadUpIsPressed pad then
        1
    else if dpadDownIsPressed pad then
        -1
    else
        0



-- left


{-| -1.0 means full left, 1.0 means full right
-}
leftX : Gamepad -> Float
leftX =
    getAxis LeftLeft LeftRight


{-| -1.0 means full down, 1.0 means full up
-}
leftY : Gamepad -> Float
leftY =
    getAxis LeftDown LeftUp


{-| -}
leftStickIsPressed : Gamepad -> Bool
leftStickIsPressed =
    isPressed LeftStick


{-| -}
leftBumperIsPressed : Gamepad -> Bool
leftBumperIsPressed =
    isPressed LeftBumper


{-| -}
leftTriggerIsPressed : Gamepad -> Bool
leftTriggerIsPressed =
    isPressed LeftTrigger


{-| 0.0 means not pressed, 1.0 means fully pressed
-}
leftTriggerValue : Gamepad -> Float
leftTriggerValue =
    getValue LeftTrigger



-- right


{-| -1.0 means full left, 1.0 means full right
-}
rightX : Gamepad -> Float
rightX =
    getAxis RightLeft RightRight


{-| -1.0 means full down, 1.0 means full up
-}
rightY : Gamepad -> Float
rightY =
    getAxis RightDown RightUp


{-| -}
rightStickIsPressed : Gamepad -> Bool
rightStickIsPressed =
    isPressed RightStick


{-| -}
rightBumperIsPressed : Gamepad -> Bool
rightBumperIsPressed =
    isPressed RightBumper


{-| -}
rightTriggerIsPressed : Gamepad -> Bool
rightTriggerIsPressed =
    isPressed RightTrigger


{-| 0.0 means not pressed, 1.0 means fully pressed
-}
rightTriggerValue : Gamepad -> Float
rightTriggerValue =
    getValue RightTrigger



--
-- Mapping helpers
--
-- This code is used to get an estimate of the buttons/sticks the user is
-- moving given a time series of RawGamepad states
--


{-| Buttons are always provided as a (isPressed, value) tuple.
The function ignores one and uses only nd always the other.

Is this a good assumption?
Are there cases where both should be considered?

-}
boolToNumber : Bool -> number
boolToNumber bool =
    if bool then
        1
    else
        0


buttonToEstimate : Int -> ( Bool, Float ) -> ( Origin, Float )
buttonToEstimate originIndex ( isPressed, value ) =
    ( Origin False Button originIndex, boolToNumber isPressed )


axisToEstimate : Int -> Float -> ( Origin, Float )
axisToEstimate originIndex value =
    ( Origin (value < 0) Axis originIndex, abs value )


estimateThreshold : ( Origin, Float ) -> Maybe Origin
estimateThreshold ( origin, confidence ) =
    if confidence < 0.5 then
        Nothing
    else
        Just origin


{-| The function guesses the Origin currently activated by the user.
-}
estimateOrigin : UnknownGamepad -> Maybe Origin
estimateOrigin (UnknownGamepad rawGamepad) =
    let
        axesEstimates =
            Array.indexedMap axisToEstimate rawGamepad.axes

        buttonsEstimates =
            Array.indexedMap buttonToEstimate rawGamepad.buttons
    in
        Array.append axesEstimates buttonsEstimates
            |> Array.toList
            |> List.sortBy Tuple.second
            |> List.reverse
            |> List.head
            |> Maybe.andThen estimateThreshold
