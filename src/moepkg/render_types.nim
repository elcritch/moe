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

## Frontend-neutral rendering value types.
##
## These types describe what moe wants to draw. Concrete frontends translate
## them to their own drawing primitives at the render-target boundary.

type
  ColorValueKind* = enum
    cvkDefault
    cvkIndexed256
    cvkRgb

  RgbColor* = object
    r*, g*, b*: uint8

  ColorValue* = object
    case kind*: ColorValueKind
    of cvkDefault:
      discard
    of cvkIndexed256:
      indexed256*: uint8
    of cvkRgb:
      rgb*: RgbColor

  StyleModifier* = enum
    Bold
    Dim
    Italic
    Underline
    SlowBlink
    RapidBlink
    Reversed
    Crossed
    Hidden
    Undercurl
    DoubleUnderline
    DottedUnderline
    DashedUnderline
    Overline

  Style* = object
    fg*, bg*: ColorValue
    modifiers*: set[StyleModifier]

func defaultColorValue*(): ColorValue {.inline.} =
  ColorValue(kind: cvkDefault)

func defaultStyle*(): Style {.inline.} =
  Style(fg: defaultColorValue(), bg: defaultColorValue(), modifiers: {})

func `==`*(a, b: RgbColor): bool {.inline.} =
  a.r == b.r and a.g == b.g and a.b == b.b

func `==`*(a, b: ColorValue): bool =
  if a.kind != b.kind:
    return false

  case a.kind
  of cvkDefault:
    true
  of cvkIndexed256:
    a.indexed256 == b.indexed256
  of cvkRgb:
    a.rgb == b.rgb

func `==`*(a, b: Style): bool {.inline.} =
  a.fg == b.fg and a.bg == b.bg and a.modifiers == b.modifiers
