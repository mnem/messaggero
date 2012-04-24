net = require 'net'
Connection = require('./connection').Connection
EventEmitter = require('events').EventEmitter

class TCPServer extends EventEmitter

    @NEW_CONNECTION_EVENT: "Server::NEW_CONNECTION_EVENT"
    @DATA_EVENT: "Server::DATA_EVENT"
    @DISCONNECTION_EVENT: "Server::DISCONNECTION_EVENT"

    count : 0

    getUniqueID: =>
        # FIXME create ids in a better way
        # maybe using the timestamp
        @count += 1


    constructor: (@port) ->
        @connections = {}
        @server = net.createServer (@onConnectionEstablished)

    writeMethod: (msg) ->
        #@socket.sendUTF msg
        @socket.write msg

    onConnectionEstablished: (socket) =>
        socket.setEncoding 'utf8'
        socket.id = @getUniqueID()
        
        currentConnection = new Connection(socket,{}, @writeMethod)
        @connections[currentConnection.id] = currentConnection

        @emit TCPServer.NEW_CONNECTION_EVENT, currentConnection


        socket.on 'end', =>
            console.log "server disconnected"
            connection = @connections[socket.id]
            connection.disconnect()
            connection.removeAllListeners()
            @emit TCPServer.DISCONNECTION_EVENT, connection
            delete @connections[socket.id]
            socket.end()

        socket.on 'data', (data) =>
            console.log "data received", data
            # removing \r\n character
            data = data.substring(0, data.length-2) while (data.length > 1 and data.charAt(data.length-2) == '\r' and data.charAt(data.length-1) == '\n')

            @emit TCPServer.DATA_EVENT, @connections[socket.id], data


    startListening: =>
        @server.listen @port, =>
            console.log "server started listening on port", @port


exports.Server = TCPServer
