require "should"
Parser = require "../Parser"
Packet = require "../Packet"

describe "PacketBuddyXML", () ->

  ###
  Basic tests
  ###

  packetHead = null
  packet = null # non initialized packet
  describe "Packet construction", () ->

    it "should correctly construct packet with name", () ->
      packetHead = new Packet("head")
      packetHead.name.should.be.eql("head")
      packetHead.packetParseData.should.be.eql([])

      packet = new Packet("name", packetHead)
      packet.name.should.be.eql("name")
      packet.packetParseData.should.be.eql([])

    it "should add uint8 to the packet parser and serialization", () ->
      packetHead.addUInt8("opcode")

      packetHead.packetParseData[0].should.be.ok
      packetHead.packetParseData[0].name.should.be.eql("opcode")

      packet.addUInt8("data")

      packet.packetParseData[0].should.be.ok
      packet.packetParseData[0].name.should.be.eql("data")

      packet.addString("string")

      packet.packetParseData[1].should.be.ok
      packet.packetParseData[1].name.should.be.eql("string")

  describe "Parser construction", () ->
    parser = new Parser(true) # is server parser
    parser.initialize()

    it "should correctly construct parser", () ->
      parser.getHead().packetParseData.should.be.eql([])

      parser.setHead(packetHead) # set head to the opcode packet
      parser.getHead().should.be.eql(packetHead)

      parser.registerPacket(packet, false, 0)
      Object.keys(parser.clientPackets).length.should.be.eql(1)

      parser.registerPacket(packet, true, 0)
      Object.keys(parser.serverPackets).length.should.be.eql(1)

    it "should serialize and parse packet", (done) ->
      parser.serialize({
        data: 5
        string: "abc"
      }, "name").then (serialized) ->
        parser.parse(serialized).then (packet) ->
          "name".should.be.eql(packet.name)
          packet.data["string"].should.be.eql("abc")
          packet.data["data"].should.be.eql(5)
          done()

  describe "Advanced tests of packet and parser", () ->
    parser = new Parser(true) # is server parser
    parser.initialize()

    it "should set the parser head", () ->
      parser.getHead().packetParseData.should.be.eql([])
      parser.setHead(packetHead)
      parser.getHead().packetParseData.length.should.be.eql(1)

    it "should add packet with array into the parser", (done) ->
      arrayPacketOne = new Packet("arrayone", packetHead)
      arrayPacketTwo = new Packet("arraytwo", packetHead)

      arrayPacketOne.addUInt8Array("numbers", 4)
      arrayPacketOne.packetParseData[0].name.should.be.eql("numbers")

      arrayPacketTwo.addUInt8Array("numbers", 6)
      arrayPacketTwo.packetParseData[0].name.should.be.eql("numbers")

      parser.registerPacket(arrayPacketOne, false, 0)
      parser.registerPacket(arrayPacketOne, true, 0)
      parser.registerPacket(arrayPacketTwo, false, 1)
      parser.registerPacket(arrayPacketTwo, true, 1)

      (parser.getPacket("arrayone")?).should.be.true # existence check

      parser.serialize({
      #opcode: 0
        numbers: [1, 2, 3, 4]
      }, "arrayone").then (serialized) ->
        parser.parse(serialized).then (packet) ->
          (packet?).should.be.true
          packet.data.opcode.should.be.eql(0)
          packet.data.numbers.should.be.eql([1,2,3,4])
          done()

    it "should try to serialize and parse second array packet", (done) ->

      parser.serialize({
      #opcode: 1
        numbers: [9, 2, 1, 4, 3, 6]
      }, "arraytwo").then (serialized) ->
        done()

    it "should correctly create two same packets", (done) ->
      packetOne = new Packet("packetOne", packetHead)
      packetTwo = new Packet("packetTwo", packetHead)

      packetOne.addUInt8("myData")
      packetTwo.addUInt8("yourData");

      packetOne.packetParseData[0].should.be.ok
      packetOne.packetParseData[0].name.should.be.eql("myData")

      parser.registerPacket(packetOne, false, 0)
      parser.registerPacket(packetOne, true, 0)

      parser.serialize({
        myData: 55
      }, "packetOne").then (serialized) ->
        parser.parse(serialized).then (packet) ->
          (packet?).should.be.true
          (packet.data.opcode?).should.be.true
          (packet.data.myData?).should.be.true
          packet.data.myData.should.be.eql(55)
          done()

  describe "Advanced #add() method packet tests", () ->

    it "should add structure to the packet with #add() method", () ->
      parser = new Parser(true)
      parser.initialize()

      parser.setHead(packetHead)
      firstPacket = new Packet("firstPacket", packetHead)

      firstPacket.add [
        something: 'uint8'
      , int: 'int32'
      ]

      firstPacket.packetParseData.length.should.be.eql(2)
      firstPacket.predefinedValues.should.be.eql({})

      firstPacket.add [
        opcode: 0
      ]

      (firstPacket.predefinedValues["opcode"]?).should.be.true
      firstPacket.predefinedValues["opcode"].should.be.eql(0)
      firstPacket.packetParseData.length.should.be.eql(2)

    it "should correctly parse and serialize advanced packet", (done) ->
      parser = new Parser(true)
      parser.initialize()

      parser.setHead(packetHead)

      firstPacket = new Packet("firstPacket", packetHead)

      firstPacket.add [
        opcode: 0
      , something: 'uint8'
      , int: 'int32'
      ]

      parser.registerPacket(firstPacket, false, 0) # client packet
      parser.registerPacket(firstPacket, true, 0) # server packet

      parser.serialize({
        something: 12
        int: 1800
      }, "firstPacket").then (serialized) ->
        parser.parse(serialized).then (packet) ->
          (packet?).should.be.true
          packet.data["opcode"].should.be.eql(0)
          packet.data["something"].should.be.eql(12)
          packet.data["int"].should.be.eql(1800)
          done()

  describe "Parser Advanced tests on incorrect xml format", () ->
    parser = null

    it "should construct and setup parser", () ->
      parser = new Parser(true)
      parser.initialize()

      parser.getHead().add({ opcode: "string" })

      parser.packet "test", true, [
        opcode: 0
      , text: "string"
      , code: "uint32"
      ]

      parser.packet "test", false, [
        opcode: 0
      , text: "string"
      , code: "uint32"
      ]

    it "should try to serialize and parse correct packet", (done) ->
      parser.serialize({
        text: "lol wtf"
        code: 42
      }, "test").then (serialized) ->
        parser.parse(serialized).then (packet) ->
          (packet?).should.be.ok
          packet.data["text"].should.be.eql("lol wtf")
          packet.data["code"].should.be.eql(42)
          done()

    it "should try to serialize partially serializable packet", (done) ->
      parser.serialize({
        text: "lol wtf"
      }, "test").then (serialized) ->
        parser.parse(serialized).then (packet) ->
          (packet?).should.be.ok
          packet.data["code"]?.should.be.true
          packet.data["text"].should.be.eql("lol wtf")
          done()
