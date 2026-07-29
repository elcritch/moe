## Shared comparisons between frontend-neutral render values and Celina values.

import pkg/celina as celina

import ../src/moepkg/render_target as rt

func toCelinaColorValue(color: rt.ColorValue): celina.ColorValue =
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

func `==`*(a: celina.ColorValue, b: rt.ColorValue): bool =
  a == b.toCelinaColorValue

func `==`*(a: rt.ColorValue, b: celina.ColorValue): bool =
  b == a

func `==`*(a: celina.Style, b: rt.Style): bool =
  a == b.toCelinaStyle

func `==`*(a: rt.Style, b: celina.Style): bool =
  b == a
