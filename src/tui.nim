import audio/[audio, context, signal]
import environment
import nimbox
import os
import strutils
import tables
import times
import words

const dumpBasename = "dump"
const dumpExtension = ".txt"
const dumpFilename = dumpBasename & dumpExtension

type
  Point = tuple[x: int, y: int]
  Node = ref object
    id: int
    inputs: seq[int]
    signal: Signal
    inputsDraft: string
    signalDraft: string
    position: Point
  State = enum
    Idle
    Pan
    Drag
    EditInputs
    EditSignal
  App = ref object
    cursor: Point
    offset: Point
    state: State
    nodes: seq[Node]
    outputs: TableRef[int, Signal]
    activeNode: Node

proc `+`(p1: Point, p2: Point): Point = (p1.x + p2.x, p1.y + p2.y)
proc `-`(p1: Point, p2: Point): Point = (p1.x - p2.x, p1.y - p2.y)
proc `+=`(p1: var Point, p2: Point) =
  p1.x += p2.x
  p1.y += p2.y

proc width(node: Node): int =
  max(
    node.inputsDraft.len + 1 + ($node.id).len + 2,
    node.signalDraft.len
  ) + 2

proc height(node: Node): int = 5

proc clientPosition(app: App, node: Node): Point = (
  node.position.x - app.offset.x,
  node.position.y - app.offset.y
)

proc getInput(app: App, i: int): Signal =
  if not app.outputs.hasKey(i):
    proc f(ctx: Context): float =
      if i < app.nodes.len:
        return app.nodes[i].signal.f(ctx)
    app.outputs[i] = Signal(f: f, label: $i).mult
  return app.outputs[i]

proc ioBarWidth(node: Node): int = node.inputsDraft.strip.len + 1 + ($node.id).len

proc signalBarWidth(node: Node): int = node.signalDraft.strip.len

proc alignBars(node: var Node) =
  let delta = node.ioBarWidth - node.signalBarWidth
  if delta > 0:
    node.inputsDraft = spaces(1) & node.inputsDraft.strip & spaces(1)
    node.signalDraft = spaces(1) & node.signalDraft.strip & spaces(delta + 1)
  elif delta < 0:
    node.inputsDraft = spaces(1) & node.inputsDraft.strip & spaces(1 - delta)
    node.signalDraft = spaces(1) & node.signalDraft.strip & spaces(1)
  else:
    node.inputsDraft = spaces(1) & node.inputsDraft.strip & spaces(1)
    node.signalDraft = spaces(1) & node.signalDraft.strip & spaces(1)

proc commitNode(app: App, node: var Node) =
  node.inputsDraft = node.inputsDraft.strip
  node.signalDraft = node.signalDraft.strip

  node.inputs.setLen(0)
  for id in node.inputsDraft.splitWhitespace:
    node.inputs &= id.parseInt

  node.alignBars

  var stack: seq[Signal] = @[]
  for i in node.inputs:
    stack &= app.getInput(i)
  for c in node.signalDraft.splitWhitespace:
    stack.execute(c)
  if stack.len > 0:
    node.signal = stack.pop
  else:
    node.signal = 0

proc draw(nb: Nimbox, app: App, node: Node) =
  let p = app.clientPosition(node)
  let x = p.x
  let y = p.y
  let width = node.width
  let crosses: array[6, Point] = [
    (x            , y),
    (x + width - 1, y),
    (x            , y + 2),
    (x + width - 1, y + 2),
    (x            , y + 4),
    (x + width - 1, y + 4)
  ]
  # for p in crosses:
    # nb.print(p.x, p.y, "+")
  nb.print(crosses[0].x, crosses[0].y, "╔")
  nb.print(crosses[1].x, crosses[1].y, "╗")
  nb.print(crosses[2].x, crosses[2].y, "╟")
  nb.print(crosses[3].x, crosses[3].y, "╢")
  nb.print(crosses[4].x, crosses[4].y, "╚")
  nb.print(crosses[5].x, crosses[5].y, "╝")
  for i in 1..(width - 2):
    for j in [0, 4]:
      nb.print(x + i, y + j, "═")
    nb.print(x + i, y + 2, "─")
  for i in [0, width - 1]:
    for j in [1, 3]:
      nb.print(x + i, y + j, "║")
  for i in 0..<node.inputsDraft.len:
    nb.print(x + 1 + i, y + 1, $node.inputsDraft[i])
  nb.print(x + 1 + node.inputsDraft.len, y, "╤")
  nb.print(x + 1 + node.inputsDraft.len, y + 1, "┼ ")
  nb.print(x + 1 + node.inputsDraft.len, y + 2, "┴")
  let id = $node.id
  for i in 0..<id.len:
    nb.print(x + width - 1 - id.len + i - 1, y + 1, $id[i])
  nb.print(x + width - 2, y + 1, " ╫")
  nb.print(x, y + 1, "╫")
  for i in 0..<node.signalDraft.len:
    nb.print(x + 1 + i, y + 3, $node.signalDraft[i])

  # connections

  for input in node.inputs:
    if input == node.id or input > app.nodes.high:
      continue
    let inode = app.nodes[input]
    let ip = app.clientPosition(inode)
    let iw = inode.width
    # easy case: inode's right side is on the left of node's left side
    # and it's enough buffer for turn
    let iright = ip.x + iw - 1 
    if iright < x:
      let dx = x - iright - 1
      let dx2 = dx div 2
      let dx3 = dx - dx2
      for i in 0..<dx2:
        nb.print(iright + 1 + i, ip.y + 1, "─")
      for i in 0..<dx3:
        nb.print(x - 1 - i, y + 1, "─")
      if ip.y < y:
        nb.print(iright + 1 + dx2, ip.y + 1, "┐")
        nb.print(x - dx3, y + 1, "└")
        for y in (ip.y + 2)..y:
          nb.print(iright + 1 + dx2, y, "│")
      elif ip.y > y:
        nb.print(iright + 1 + dx2, ip.y + 1, "┘")
        nb.print(x - dx3, y + 1, "┌")
        for y in (y + 2)..(ip.y):
          nb.print(iright + 1 + dx2, y, "│")
    elif iright == x:
      let minY = min(y, ip.y)
      let maxY = max(y, ip.y)
      for y in (minY + 5)..(maxY - 1):
        nb.print(x, y, "│")
    else:
        nb.print(iright + 1, ip.y + 1, "─⊙")
        nb.print(x - 2, y + 1, "⊙─")

proc inside(app: App, node: Node, p: Point): bool =
  let c = app.clientPosition(node)
  return p.x >= c.x and p.x < c.x + node.width and p.y >= c.y and p.y < c.y + node.height

proc serialize(app: App): string =
  result = ""
  for node in app.nodes:
    result &= "$#|$#|$#,$#\n" % [
      node.inputsDraft.strip,
      node.signalDraft.strip,
      $node.position.x,
      $node.position.y
    ]

proc deserialize(s: string, env: Environment): App =
  result = App(nodes: @[], outputs: newTable[int, Signal]())
  for line in s.splitLines:
    let draft = line.split("|")
    if draft.len < 3:
      continue
    let position = draft[2].split(",")
    var node = Node(
      id: result.nodes.len,
      inputs: @[],
      signal: 0,
      inputsDraft: draft[0],
      signalDraft: draft[1],
      position: (position[0].parseInt, position[1].parseInt)
    )
    result.nodes &= node
    result.commitNode(node)
  for i in 0..<MAX_STREAMS:
    env.streams[i].signal = result.getInput(i)

proc run*(env: Environment) =
  var nb = newNimbox()
  defer: nb.shutdown()

  nb.inputMode = InputMode.inpMouse

  var app = App(nodes: @[], outputs: newTable[int, Signal]())

  var evt: Event

  for i in 0..<MAX_STREAMS:
    var node = Node(
      id: i,
      inputs: @[],
      signal: 0,
      inputsDraft: "",
      signalDraft: "0",
      position: (10, 6 * i)
    )
    node.alignBars
    app.nodes &= node
    env.streams[i].signal = app.getInput(i)

  while true:
    nb.clear()
    for node in app.nodes:
      nb.draw(app, node)
    case app.state:
    of EditInputs, EditSignal:
      nb.cursor = app.cursor
    else:
      nb.cursor = (-1, -1)
    nb.present()

    evt = nb.pollEvent
    case evt.kind:
    of EventType.Key:
      if evt.sym == Symbol.Escape:
        break
      case app.state
      of EditInputs:
        let node = app.activeNode
        let c = app.cursor
        let p = app.clientPosition(node)
        let i = c.x - p.x - 1
        case evt.sym:
        of Symbol.Enter:
          app.commitNode(app.activeNode)
          app.state = Idle
          app.activeNode = nil
        of Symbol.Left:
          if i > 0:
            app.cursor.x -= 1
        of Symbol.Right:
          if i < node.inputsDraft.high:
            app.cursor.x += 1
        of Symbol.Delete:
          if i < node.inputsDraft.high:
            node.inputsDraft.delete(i, i)
        of Symbol.Backspace:
          if i > 0:
            node.inputsDraft.delete(i - 1, i - 1)
            app.cursor.x -= 1
        of Symbol.Character, Symbol.Space:
          node.inputsDraft.insert($evt.ch, i)
          app.cursor.x += 1
        else: discard
      of EditSignal:
        let node = app.activeNode
        let c = app.cursor
        let p = app.clientPosition(node)
        let i = c.x - p.x - 1
        case evt.sym:
        of Symbol.Enter:
          app.commitNode(app.activeNode)
          app.state = Idle
          app.activeNode = nil
        of Symbol.Left:
          if i > 0:
            app.cursor.x -= 1
        of Symbol.Right:
          if i < node.signalDraft.high:
            app.cursor.x += 1
        of Symbol.Delete:
          if i < node.signalDraft.high:
            node.signalDraft.delete(i, i)
        of Symbol.Backspace:
          if i > 0:
            node.signalDraft.delete(i - 1, i - 1)
            app.cursor.x -= 1
        of Symbol.Character, Symbol.Space:
          node.signalDraft.insert($evt.ch, i)
          app.cursor.x += 1
        else: discard
      of Idle:
        case evt.ch
        of '/':
          if dumpFilename.fileExists:
            dumpFilename.copyFile(dumpBasename & $epochTime() & dumpExtension)
          dumpFilename.writeFile(app.serialize)
        of '\\':
          if dumpFilename.fileExists:
            app = dumpFilename.readFile.deserialize(env)
        else: discard
      else: discard
    of EventType.Mouse:
      let p: Point = (cast[int](evt.x), cast[int](evt.y))
      case app.state
      of Idle:
        case evt.action:
        of Left:
          for node in app.nodes:
            if app.inside(node, p):
              app.state = Drag
              app.activeNode = node
              break
          if app.state == Idle:
            app.state = Pan
        of Right:
          var insideNode = false
          for node in app.nodes:
            if app.inside(node, p):
              insideNode = true
              let c = app.clientPosition(node)
              if p.y == c.y + 1 and p.x > c.x and p.x <= c.x + node.inputsDraft.len:
                app.state = EditInputs
                app.activeNode = node
              elif p.y == c.y + 3 and p.x > c.x and p.x <= c.x + node.signalDraft.len:
                app.state = EditSignal
                app.activeNode = node
              break
          if not insideNode:
            let i = app.nodes.len
            var node = Node(
              id: i,
              inputs: @[],
              signal: 0,
              inputsDraft: "",
              signalDraft: "0",
              position: p + app.offset
            )
            node.alignBars
            app.nodes &= node
        else: discard
      of Pan:
        case evt.action:
        of Left:
          app.offset += app.cursor - p
        of Release:
          app.state = Idle
        else: discard
      of Drag:
        case evt.action:
        of Left:
          app.activeNode.position += p - app.cursor 
        of Release:
          app.state = Idle
          app.activeNode = nil
        else: discard
      of EditInputs:
        case evt.action:
        of Left:
          app.commitNode(app.activeNode)
          app.state = Idle
          app.activeNode = nil
        else: discard
      of EditSignal:
        case evt.action:
        of Left:
          app.commitNode(app.activeNode)
          app.state = Idle
          app.activeNode = nil
        else: discard
      app.cursor = p

    else: discard



