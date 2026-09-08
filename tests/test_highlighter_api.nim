## Exercise only the public facades used by host applications, without TOML.
import std/[os, tempfiles, unittest]
import pkg/results
import ../src/moepkg/[buffer, config, editor, highlight]

when defined(moe.matter) or defined(features.moe.matter):
  import ../src/moepkg/syntax/matter_backend
  import matter_test_grammars

suite "Programmatic highlighter selection":
  test "buffer facade exposes selection and effective fallback":
    let buffer = newTextBuffer("let x = true")
    buffer.language = langNim
    buffer.setHighlightBackend(hbMatter)
    check buffer.highlightBackend == hbMatter
    check buffer.effectiveHighlightBackend == hbBuiltin
    when defined(moe.matter) or defined(features.moe.matter):
      buffer.setMatterGrammar(langNim, NimMatterGrammar, "nim.tmLanguage.json")
      check buffer.effectiveHighlightBackend == hbMatter
    else:
      check buffer.effectiveHighlightBackend == hbBuiltin
    discard buffer.updateHighlight()
    check buffer.incrementalHighlight.backend == buffer.effectiveHighlightBackend
    buffer.setHighlightBackend(hbBuiltin)
    check buffer.incrementalHighlight.isNil
    check buffer.highlightNeedsUpdate
    check buffer.effectiveHighlightBackend == hbBuiltin

  test "editor setter updates existing buffers and future buffer defaults":
    let config = newEditorConfig()
    config.lsp.enable = false
    config.clipboard.enable = false
    let editor = newEditor(config)
    let extra = newTextBuffer("# extra")
    extra.language = langNim
    editor.addBuffer(extra)
    let current = editor.activeBuffer()
    current.language = langNim
    discard current.updateHighlight()
    let originalHighlight = current.highlight

    editor.setHighlightBackend(hbMatter)
    check editor.config.highlight.backend == hbMatter
    check editor.state.config.highlight.backend == hbMatter
    for buffer in editor.buffers:
      check buffer.highlightBackend == hbMatter
      check buffer.highlightNeedsUpdate
      check buffer.effectiveHighlightBackend == hbBuiltin
    check current.highlight == originalHighlight

    when defined(moe.matter) or defined(features.moe.matter):
      editor.setMatterGrammar(langNim, NimMatterGrammar, "nim.tmLanguage.json")
      for buffer in editor.buffers:
        check buffer.effectiveHighlightBackend == hbMatter

    let directory = createTempDir("moe_highlighter_api_", "")
    defer:
      removeDir(directory)
    let opened = editor.loadOrCreateBuffer(directory / "future.nim")
    require opened.isOk
    check opened.get.highlightBackend == hbMatter
    when defined(moe.matter) or defined(features.moe.matter):
      check opened.get.effectiveHighlightBackend == hbMatter
    else:
      check opened.get.effectiveHighlightBackend == hbBuiltin

    editor.setHighlightBackend(hbBuiltin)
    check editor.config.highlight.backend == hbBuiltin
    for buffer in editor.buffers:
      check buffer.effectiveHighlightBackend == hbBuiltin

  test "backend configuration alone does not opt into Matter":
    let config = newEditorConfig()
    config.lsp.enable = false
    config.clipboard.enable = false
    config.highlight.backend = hbMatter
    let editor = newEditor(config)
    editor.activeBuffer().language = langNim
    check editor.activeBuffer().effectiveHighlightBackend == hbBuiltin

  when defined(moe.matter) or defined(features.moe.matter):
    test "editor setter registers a dynamic grammar for current and future buffers":
      let
        config = newEditorConfig()
        editor = newEditor(config)
        directory = createTempDir("moe_dynamic_highlighter_api_", "")
      defer:
        removeDir(directory)

      let existing = editor.loadOrCreateBuffer(directory / "existing.hcl")
      require existing.isOk
      check existing.get.effectiveHighlightBackend == hbBuiltin

      editor.setMatterGrammar(
        MatterGrammarSource(
          content: TerraformMatterGrammar,
          path: "terraform.tmLanguage.json",
          fileTypes: @["hcl"],
        )
      )
      check existing.get.effectiveHighlightBackend == hbMatter

      let future = editor.loadOrCreateBuffer(directory / "future.hcl")
      require future.isOk
      check future.get.language == langNone
      check future.get.effectiveHighlightBackend == hbMatter

  test "invalid or unavailable grammar API does not change backend":
    let buffer = newTextBuffer("let x = true")
    buffer.language = langNim
    when defined(moe.matter) or defined(features.moe.matter):
      expect TextMateGrammarError:
        buffer.setMatterGrammar(langNim, "{", "invalid.tmLanguage.json")
    else:
      expect TextMateGrammarError:
        buffer.setMatterGrammar(langNim, "{}")
    check buffer.highlightBackend == hbBuiltin

  test "per-buffer override does not change the editor default":
    let config = newEditorConfig()
    config.lsp.enable = false
    config.clipboard.enable = false
    let editor = newEditor(config)
    let buffer = editor.activeBuffer()
    buffer.language = langDiff
    buffer.setHighlightBackend(hbMatter)
    check buffer.effectiveHighlightBackend == hbBuiltin
    check editor.config.highlight.backend == hbBuiltin
