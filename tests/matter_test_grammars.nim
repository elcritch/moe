when defined(moe.matter) or defined(features.moe.matter):
  import ../src/moepkg/syntax/[matter_backend, tokenizer]

  const
    NimMatterGrammar* =
      """
{
  "name": "Nim test grammar",
  "scopeName": "source.nim",
  "patterns": [
    {"include": "#blockComment"},
    {"match": "#.*$", "name": "comment.line.number-sign.nim"},
    {"match": "\\b(true|false)\\b", "name": "constant.language.boolean.nim"},
    {"match": "\\b(proc|let|discard)\\b", "name": "keyword.nim"},
    {"match": "\\b[0-9]+\\b", "name": "constant.numeric.nim"}
  ],
  "repository": {
    "blockComment": {
      "begin": "#\\[",
      "end": "\\]#",
      "name": "comment.block.nim",
      "patterns": [{"include": "#blockComment"}]
    }
  }
}
"""

    JsoncMatterGrammar* =
      """
{
  "name": "JSONC test grammar",
  "scopeName": "source.json.comments",
  "patterns": [
    {"match": "//.*$", "name": "comment.line.double-slash.jsonc"},
    {"match": "\\b(true|false|null)\\b", "name": "constant.language.jsonc"}
  ]
}
"""

    MarkdownMatterGrammar* =
      """
{
  "name": "Markdown test grammar",
  "scopeName": "text.html.markdown",
  "patterns": [
    {
      "begin": "^(```|~~~).*$",
      "end": "^\\1\\s*$",
      "name": "markup.fenced_code.block.markdown"
    }
  ]
}
"""

    TerraformMatterGrammar* =
      """
{
  "name": "Terraform test grammar",
  "scopeName": "source.hcl.terraform",
  "fileTypes": ["tf", "tfvars"],
  "patterns": [
    {"match": "\\b(true|false|null)\\b", "name": "constant.language.hcl"},
    {"begin": "\"", "end": "\"", "name": "string.quoted.double.hcl"}
  ]
}
"""

    AlternateHclMatterGrammar* =
      """
{
  "name": "Alternate HCL test grammar",
  "scopeName": "source.hcl.alternate",
  "fileTypes": ["hcl"],
  "patterns": [
    {"match": "\\b(true|false|null)\\b", "name": "keyword.control.hcl"}
  ]
}
"""

  proc newTestMatterGrammarSet*(): MatterGrammarSet =
    newMatterGrammarSet(
      [
        MatterGrammarSource(
          content: NimMatterGrammar, path: "nim.tmLanguage.json", language: langNim
        ),
        MatterGrammarSource(
          content: JsoncMatterGrammar,
          path: "jsonc.tmLanguage.json",
          language: langJsonc,
        ),
        MatterGrammarSource(
          content: MarkdownMatterGrammar,
          path: "markdown.tmLanguage.json",
          language: langMarkdown,
          fileTypes: @["mdx"],
        ),
        MatterGrammarSource(
          content: TerraformMatterGrammar,
          path: "terraform.tmLanguage.json",
          fileTypes: @["hcl"],
        ),
      ]
    )
