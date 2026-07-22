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

## Celina adapter for moe's frontend-neutral render target.

import pkg/celina as celina

import std/unicode

import render_target as rt

func toRenderRect*(area: celina.Rect): rt.RenderRect {.inline.} =
  rt.RenderRect(x: area.x, y: area.y, width: area.width, height: area.height)

func toCelinaRect*(area: rt.RenderRect): celina.Rect {.inline.} =
  celina.Rect(x: area.x, y: area.y, width: area.width, height: area.height)

func toCelinaColorValue*(color: rt.ColorValue): celina.ColorValue =
  case color.kind
  of rt.cvkDefault:
    celina.ColorValue(kind: celina.Default)
  of rt.cvkIndexed256:
    celina.ColorValue(kind: celina.Indexed256, indexed256: color.indexed256)
  of rt.cvkRgb:
    celina.ColorValue(
      kind: celina.Rgb,
      rgb: celina.RgbColor(r: color.rgb.r, g: color.rgb.g, b: color.rgb.b),
    )

func toCelinaModifiers(modifiers: set[rt.StyleModifier]): set[celina.StyleModifier] =
  for modifier in modifiers:
    case modifier
    of rt.StyleModifier.Bold:
      result.incl(celina.StyleModifier.Bold)
    of rt.StyleModifier.Dim:
      result.incl(celina.StyleModifier.Dim)
    of rt.StyleModifier.Italic:
      result.incl(celina.StyleModifier.Italic)
    of rt.StyleModifier.Underline:
      result.incl(celina.StyleModifier.Underline)
    of rt.StyleModifier.SlowBlink:
      result.incl(celina.StyleModifier.SlowBlink)
    of rt.StyleModifier.RapidBlink:
      result.incl(celina.StyleModifier.RapidBlink)
    of rt.StyleModifier.Reversed:
      result.incl(celina.StyleModifier.Reversed)
    of rt.StyleModifier.Crossed:
      result.incl(celina.StyleModifier.Crossed)
    of rt.StyleModifier.Hidden:
      result.incl(celina.StyleModifier.Hidden)
    of rt.StyleModifier.Undercurl:
      result.incl(celina.StyleModifier.Undercurl)
    of rt.StyleModifier.DoubleUnderline:
      result.incl(celina.StyleModifier.DoubleUnderline)
    of rt.StyleModifier.DottedUnderline:
      result.incl(celina.StyleModifier.DottedUnderline)
    of rt.StyleModifier.DashedUnderline:
      result.incl(celina.StyleModifier.DashedUnderline)
    of rt.StyleModifier.Overline:
      result.incl(celina.StyleModifier.Overline)

func toCelinaStyle*(style: rt.Style): celina.Style =
  celina.Style(
    fg: style.fg.toCelinaColorValue,
    bg: style.bg.toCelinaColorValue,
    modifiers: style.modifiers.toCelinaModifiers,
  )

proc setCelinaCell(
    context: pointer, x, y: int, symbol: string, width: int, style: rt.Style
) =
  let buffer = cast[ptr celina.Buffer](context)
  buffer[].setCell(x, y, symbol, width, style.toCelinaStyle)

proc setCelinaString(context: pointer, x, y: int, text: string, style: rt.Style) =
  let buffer = cast[ptr celina.Buffer](context)
  buffer[].setString(x, y, text, style.toCelinaStyle)

proc foldCelinaZeroWidthRune(context: pointer, x, y: int, rune: Rune) =
  let buffer = cast[ptr celina.Buffer](context)
  buffer[].foldZeroWidthRune(x, y, rune)

proc initCelinaRenderTarget*(buffer: var celina.Buffer): rt.RenderTarget =
  rt.initRenderTarget(
    buffer.area.toRenderRect, buffer.addr, setCelinaCell, setCelinaString,
    foldCelinaZeroWidthRune,
  )
