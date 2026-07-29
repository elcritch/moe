#[###################### GNU General Public License 3.0 ######################]#
#                                                                              #
#  Copyright (C) 2017─2026 Shuhei Nogawa                                       #
#                                                                              #
#  This program is free software: you can redistribute it and/or modify        #
#  it under the terms of the GNU General Public License as published by        #
#  the Free Software Foundation, either version 3 of the License, or           #
#  (at your option) any later version.                                         #
#                                                                              #
#  This program is distributed in the hope that it will be useful,             #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of              #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               #
#  GNU General Public License for more details.                                #
#                                                                              #
#  You should have received a copy of the GNU General Public License           #
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.      #
#                                                                              #
#[############################################################################]#

## Frontend-neutral drawing target.
##
## Editor render code writes to this target instead of a concrete terminal
## buffer. Frontends provide the callbacks that translate moe's render cells and
## styles to their own drawing backend.

import std/unicode

import render_types

export render_types

type
  RenderRect* = object
    x*, y*, width*, height*: int

  RenderSetCellFn* =
    proc(context: pointer, x, y: int, symbol: string, width: int, style: Style)
  RenderSetStringFn* = proc(context: pointer, x, y: int, text: string, style: Style)
  RenderFoldZeroWidthRuneFn* = proc(context: pointer, x, y: int, rune: Rune)

  RenderTarget* = object
    area*: RenderRect
    context: pointer
    setCellImpl: RenderSetCellFn
    setStringImpl: RenderSetStringFn
    foldZeroWidthRuneImpl: RenderFoldZeroWidthRuneFn

proc initRenderTarget*(
    area: RenderRect,
    context: pointer,
    setCellImpl: RenderSetCellFn,
    setStringImpl: RenderSetStringFn,
    foldZeroWidthRuneImpl: RenderFoldZeroWidthRuneFn,
): RenderTarget =
  doAssert not setCellImpl.isNil, "RenderTarget requires a setCell callback"
  doAssert not setStringImpl.isNil, "RenderTarget requires a setString callback"
  doAssert not foldZeroWidthRuneImpl.isNil,
    "RenderTarget requires a zero-width-rune callback"

  RenderTarget(
    area: area,
    context: context,
    setCellImpl: setCellImpl,
    setStringImpl: setStringImpl,
    foldZeroWidthRuneImpl: foldZeroWidthRuneImpl,
  )

proc setCell*(
    target: var RenderTarget,
    x, y: int,
    symbol: string,
    width: int,
    style: Style = defaultStyle(),
) {.inline.} =
  target.setCellImpl(target.context, x, y, symbol, width, style)

proc setCell*(
    target: var RenderTarget,
    x, y: int,
    rune: Rune,
    width: int,
    style: Style = defaultStyle(),
) {.inline.} =
  target.setCell(x, y, $rune, width, style)

proc setString*(
    target: var RenderTarget, x, y: int, text: string, style: Style = defaultStyle()
) {.inline.} =
  target.setStringImpl(target.context, x, y, text, style)

proc fill*(
    target: var RenderTarget,
    area: RenderRect,
    symbol: string,
    width: int,
    style: Style = defaultStyle(),
) =
  let
    startX = max(area.x, target.area.x)
    startY = max(area.y, target.area.y)
    endX = min(area.x + area.width, target.area.x + target.area.width)
    endY = min(area.y + area.height, target.area.y + target.area.height)

  for y in startY ..< endY:
    for x in startX ..< endX:
      target.setCell(x, y, symbol, width, style)

proc foldZeroWidthRune*(target: var RenderTarget, x, y: int, rune: Rune) {.inline.} =
  target.foldZeroWidthRuneImpl(target.context, x, y, rune)
