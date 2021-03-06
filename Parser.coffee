Promise = require("promise")
{parseString} = require("xml2js")
xml = require("xml2js")
Packet = require("./Packet")

module.exports = class Parser

  constructor: (@isServer) ->
    @head = new Packet("Head")
    @builder = null

    @serverPackets = { }
    @clientPackets = { }
    @packetConditions = { }

  ###
    @injectable
  ###
  initialize: (rootNode = "root", conditionField = "opcode") ->
    @rootNode = rootNode
    @conditionField = conditionField

    @builder = new xml.Builder({
      rootName: @rootNode
    })

  ###
    @return [Packet] packet representing head for all packets
  ###
  getHead: () =>
    return @head

  ###
    sets the current head to the given

    @param head [Packet] packet to be given as a head packet
    @return [Packet] new head packet instance
  ###
  setHead: (head) =>
    @head = head
    return @head

  ###
    Sets the condition field to the custom one

    @param conditionField[String] name of condition field in packet
  ###
  setConditionField:(@conditionField) ->

  registerPacket: (packet, isServerPacket, condition = null) ->

    if isServerPacket # switch between server and client packets
      @serverPackets[packet.name] = packet
    else
      @clientPackets[packet.name] = packet

    # register condition for current packet
    if (@isServer and not isServerPacket) or (not @isServer and isServerPacket)
      @registerCondition(packet.name, condition)
    else
      packet.addPredefinedValue(@conditionField, condition) # adds as predefined value

    return packet

  packet: (name, isServerPacket, structure) =>
    condition = @findCondition(structure) # get additional condition

    packet = new Packet(name, @head)
    packet.add(structure)

    return @registerPacket(packet, isServerPacket, condition)

  ###
  Finds condition field value in the packet structure

  @param structure [Array] an array of structured for the packet
  @return [String|Integer|Null] value of condition field or null if not found
  ###
  findCondition: (structure) ->
    for field in structure
      for name, value of field
        if name is @conditionField
          return value

    return null

  ###
  Returns packet from collection by given type

  @param packetName [String] packet name from collection
  @param isServer [Boolean] true if server packet is needed, else false. Default: true
  ###
  getPacket: (packetName, isServer = true) =>
    return if isServer then @serverPackets[packetName] else @clientPackets[packetName]

  registerCondition: (packetName, condition = null) ->
    if condition? and packetName?
      @packetConditions[condition] = packetName

  # parse given data by code tables
  parse: (data, packetName = null) =>
    return new Promise (fulfill, reject) =>
      parsedData = { }

      parseString data.toString(), (err, result) =>
        parsed = result[Object.keys(result)[0]]

        # parse head
        if @getHead()?
          # type is now ignored due to xml
          for parser in @getHead().packetParseData
            parsedData[parser["name"]] = if parsed[parser.name]? then parser["read"](parsed) else null

        # retrieve condition from the parsed data ( should this be in head ? )
        condition = parsed[@conditionField][0]

        name = if packetName? then packetName else @packetConditions[condition]
        packet = @getPacket(name, !@isServer)

        if not packet?
          reject(new Error("Packet not found"))
          return

        # parse body
        for parser in packet.packetParseData
          parsedData[parser["name"]] = if parsed[parser.name]? then parser["read"](parsed)

        fulfill({name: name, data: parsedData})

  serialize: (data, packetName) =>
    return new Promise (fulfill, reject) =>
      packet = @getPacket(packetName, @isServer)

      for name, value of packet.predefinedValues
        data[name] = value if not data[name]? # assign default value if not defined

      @builder.options.rootName = packetName
      fulfill(@builder.buildObject(data))
