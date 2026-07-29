## Tests for the frontend-neutral render-target contract.

import std/[unicode, unittest]

import ../src/moepkg/[render_target, unicode_utils]

type
  CellCall = object
    x, y: int
    symbol: string
    width: int
    style: Style

  StringCall = object
    x, y: int
    text: string
    style: Style

  RuneCall = object
    x, y: int
    rune: Rune

  TargetRecorder = object
    cells: seq[CellCall]
    strings: seq[StringCall]
    zeroWidthRunes: seq[RuneCall]

proc recordCell(context: pointer, x, y: int, symbol: string, width: int, style: Style) =
  let recorder = cast[ptr TargetRecorder](context)
  recorder[].cells.add(CellCall(x: x, y: y, symbol: symbol, width: width, style: style))

proc recordString(context: pointer, x, y: int, text: string, style: Style) =
  let recorder = cast[ptr TargetRecorder](context)
  recorder[].strings.add(StringCall(x: x, y: y, text: text, style: style))

proc recordZeroWidthRune(context: pointer, x, y: int, rune: Rune) =
  let recorder = cast[ptr TargetRecorder](context)
  recorder[].zeroWidthRunes.add(RuneCall(x: x, y: y, rune: rune))

proc initRecordingTarget(recorder: var TargetRecorder): RenderTarget =
  initRenderTarget(
    RenderRect(x: 0, y: 0, width: 20, height: 10),
    recorder.addr,
    recordCell,
    recordString,
    recordZeroWidthRune,
  )

suite "RenderTarget":
  test "dispatches drawing operations with their complete values":
    var recorder: TargetRecorder
    var target = recorder.initRecordingTarget()
    let style = Style(
      fg: ColorValue(kind: cvkIndexed256, indexed256: 1),
      bg: ColorValue(kind: cvkIndexed256, indexed256: 2),
      modifiers: {StyleModifier.Bold},
    )

    target.setCell(2, 3, "界", 2, style)
    target.setString(4, 5, "text", style)
    target.foldZeroWidthRune(6, 7, Rune(0x0301))

    check recorder.cells ==
      @[CellCall(x: 2, y: 3, symbol: "界", width: 2, style: style)]
    check recorder.strings == @[StringCall(x: 4, y: 5, text: "text", style: style)]
    check recorder.zeroWidthRunes == @[RuneCall(x: 6, y: 7, rune: Rune(0x0301))]

  test "setRuneCell preserves wide-rune display width":
    var recorder: TargetRecorder
    var target = recorder.initRecordingTarget()

    check setRuneCell(target, 1, 2, "界".runeAt(0), defaultStyle()) == 2
    check recorder.cells.len == 1
    check recorder.cells[0].symbol == "界"
    check recorder.cells[0].width == 2

  test "setRuneCell delegates zero-width runes":
    var recorder: TargetRecorder
    var target = recorder.initRecordingTarget()
    let combiningMark = Rune(0x0301)

    check setRuneCell(target, 3, 4, combiningMark, defaultStyle()) == 0
    check recorder.cells.len == 0
    check recorder.zeroWidthRunes == @[RuneCall(x: 3, y: 4, rune: combiningMark)]

  test "fill clips writes to the target area":
    var recorder: TargetRecorder
    var target = recorder.initRecordingTarget()

    target.fill(RenderRect(x: 18, y: 9, width: 4, height: 3), " ", 1)

    check recorder.cells.len == 2
    check recorder.cells[0].x == 18
    check recorder.cells[0].y == 9
    check recorder.cells[1].x == 19
    check recorder.cells[1].y == 9

  test "constructor rejects missing callbacks":
    var recorder: TargetRecorder
    let area = RenderRect(x: 0, y: 0, width: 1, height: 1)

    expect AssertionDefect:
      discard
        initRenderTarget(area, recorder.addr, nil, recordString, recordZeroWidthRune)
    expect AssertionDefect:
      discard
        initRenderTarget(area, recorder.addr, recordCell, nil, recordZeroWidthRune)
    expect AssertionDefect:
      discard initRenderTarget(area, recorder.addr, recordCell, recordString, nil)
