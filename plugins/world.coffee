fs = require 'fs'
Connection = require('../connection').Connection
Packet = require('../packet').Packet


class World
    @BROADCAST_TO_ROOM_EVENT: "World::BROADCAST_TO_ROOM::"

    description: "World"

    commands: =>
        world: @world,
        join: @join

    constructor: ->
        @worlds = {}
        fs.readFile './data/worlds.json', 'utf8', @loadWorlds

    loadWorlds: (err, data) =>
        worlds = JSON.parse data
        # create each room
       
        for world, rooms of worlds
            @worlds[world] = {}
            @worlds[world]["rooms"] = {}
            @worlds[world]["rooms"]["lobby"] = new Room("lobby")
            for room in rooms
                r = new Room(room)
                @worlds[world]["rooms"][room] = r


    #notifications from plugin manager
    onNewConnection: (connection) =>

    onConnectionDisconnected: (connection) =>
    #--

    execute: (connection, msgPacket) =>

        # users need to be logged in to be able to
        # use the chat
        if not (connection.getData("username")?)
            console.log "not logged in"
            return

        @commands()[msgPacket.command](connection, msgPacket)
        connection.socket.write msgPacket.command+" executed"


    world: (connection, msgPacket) =>
        
        if msgPacket.messageFragments.length != 1
            msg = new Packet msgPacket.separator, "KO", ["bad request"]
            return connection.emit Connection.SEND_PACKET_EVENT, msg

        worldToJoin = msgPacket.messageFragments[0]
        if not @worlds[worldToJoin]?
            msg = new Packet msgPacket.separator, "world", ["NO",worldToJoin]
            return connection.emit Connection.SEND_PACKET_EVENT, msg

        # automatically join the lobby

        connection.setData "world", worldToJoin
        connection.setData "room", "lobby"

        console.log "about to join lobby "+connection.id
        @worlds[worldToJoin]["rooms"]["lobby"].join(connection)
        msg = new Packet msgPacket.separator, "world", ["IN", worldToJoin]
        connection.emit Connection.SEND_PACKET_EVENT, msg

    join: (connection, msgPacket) =>

        if msgPacket.messageFragments.length != 1
            msg = new Packet msgPacket.separator, "KO", ["bad request"]
            return connection.emit Connection.SEND_PACKET_EVENT, msg

        roomToJoin = msgPacket.messageFragments[0]
        currentWorld = connection.getData("world")
       
        
        if not (currentWorld?)
            msg = new Packet msgPacket.separator, "KO", ["not in a world"]
            return connection.emit Connection.SEND_PACKET_EVENT, msg

        currentRoom = connection.getData("room")

        if not (@worlds[currentWorld]["rooms"][roomToJoin]?)
            msg = new Packet msgPacket.separator, "room", ["NO", roomToJoin]
            return connection.emit Connection.SEND_PACKET_EVENT, msg


        @worlds[currentWorld]["rooms"][currentRoom].leave(connection)

        @worlds[currentWorld]["rooms"][roomToJoin].join(connection)

        connection.setData "room", roomToJoin

        msg = new Packet msgPacket.separator, "room", ["IN", roomToJoin]
        connection.emit Connection.SEND_PACKET_EVENT, msg



exports.Plugin = World



class Room

    constructor: (@id) ->
        @connections = {}

    join: (connection) =>
        console.log connection.getData("username"), "joining", @id
        @connections[connection.id] = connection
        connection.on World.BROADCAST_TO_ROOM_EVENT+@id, @broadcast

    leave: (connection) =>
        connection.removeListener World.BROADCAST_TO_ROOM_EVENT+@id, @broadcast
        console.log connection.getData("username"), "leaving", @id
        delete @connections[connection.id]

    broadcast: (sourceConnection, sourcePacket) =>
        actualMessage = sourcePacket.messageFragments[0]
        msg = new Packet sourcePacket.separator, "sez", []
        sourceUsername = sourceConnection.getData("username")
        for id, connection of @connections
            # we don't want to echo back
            if sourceConnection.id.toString() isnt id.toString()
                msg.messageFragments = [sourceUsername, actualMessage]
                connection.emit Connection.SEND_PACKET_EVENT, msg

