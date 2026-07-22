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

import render_target

func toRenderRect*(area: celina.Rect): RenderRect {.inline.} =
  RenderRect(x: area.x, y: area.y, width: area.width, height: area.height)

func toCelinaRect*(area: RenderRect): celina.Rect {.inline.} =
  celina.Rect(x: area.x, y: area.y, width: area.width, height: area.height)

func toCelinaColorValue*(color: ColorValue): celina.ColorValue =
  case color.kind
  of cvkDefault:
    celina.ColorValue(kind: celina.Default)
  of cvkIndexed256:
    celina.ColorValue(kind: celina.Indexed256, indexed256: color.indexed256)
  of cvkRgb:
    celina.ColorValue(
      kind: celina.Rgb,
      rgb: celina.RgbColor(r: color.rgb.r, g: color.rgb.g, b: color.rgb.b),
    )

func toCelinaModifiers(modifiers: set[StyleModifier]): set[celina.StyleModifier] =
  for modifier in modifiers:
    case modifier
    of StyleModifier.Bold:
      result.incl(celina.StyleModifier.Bold)
    of StyleModifier.Dim:
      result.incl(celina.StyleModifier.Dim)
    of StyleModifier.Italic:
      result.incl(celina.StyleModifier.Italic)
    of StyleModifier.Underline:
      result.incl(celina.StyleModifier.Underline)
    of StyleModifier.SlowBlink:
      result.incl(celina.StyleModifier.SlowBlink)
    of StyleModifier.RapidBlink:
      result.incl(celina.StyleModifier.RapidBlink)
    of StyleModifier.Reversed:
      result.incl(celina.StyleModifier.Reversed)
    of StyleModifier.Crossed:
      result.incl(celina.StyleModifier.Crossed)
    of StyleModifier.Hidden:
      result.incl(celina.StyleModifier.Hidden)
    of StyleModifier.Undercurl:
      result.incl(celina.StyleModifier.Undercurl)
    of StyleModifier.DoubleUnderline:
      result.incl(celina.StyleModifier.DoubleUnderline)
    of StyleModifier.DottedUnderline:
      result.incl(celina.StyleModifier.DottedUnderline)
    of StyleModifier.DashedUnderline:
      result.incl(celina.StyleModifier.DashedUnderline)
    of StyleModifier.Overline:
      result.incl(celina.StyleModifier.Overline)

func toCelinaStyle*(style: Style): celina.Style =
  celina.Style(
    fg: style.fg.toCelinaColorValue,
    bg: style.bg.toCelinaColorValue,
    modifiers: style.modifiers.toCelinaModifiers,
  )

proc setCelinaCell(
    context: pointer, x, y: int, symbol: string, width: int, style: Style
) =
  let buffer = cast[ptr celina.Buffer](context)
  buffer[].setCell(x, y, symbol, width, style.toCelinaStyle)

proc setCelinaString(context: pointer, x, y: int, text: string, style: Style) =
  let buffer = cast[ptr celina.Buffer](context)
  buffer[].setString(x, y, text, style.toCelinaStyle)

proc foldCelinaZeroWidthRune(context: pointer, x, y: int, rune: Rune) =
  let buffer = cast[ptr celina.Buffer](context)
  buffer[].foldZeroWidthRune(x, y, rune)

proc initCelinaRenderTarget*(buffer: var celina.Buffer): RenderTarget =
  initRenderTarget(
    buffer.area.toRenderRect, buffer.addr, setCelinaCell, setCelinaString,
    foldCelinaZeroWidthRune,
  )
