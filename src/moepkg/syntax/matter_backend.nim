## Optional Matter TextMate adapter. Moe does not bundle grammars: callers add
## grammar source explicitly, either through the public editor/buffer API or
## through files named by the user's configuration. Matter can select grammars
## by their TextMate file types without adding them to `SourceLanguage`.

when not (defined(moe.matter) or defined(features.moe.matter)):
  {.error: "moepkg/syntax/matter_backend requires the Matter feature".}

import std/[os, sets, strutils, tables]
import matter/[engine, grammarpackages, rawgrammar]

import tokenizer
import ../[logger, unicode_utils]
import ../types/highlight_types

const MatterTimeLimitMs* {.intdefine.} = 20
  ## Soft per-line deadline. Override with -d:matterTimeLimitMs=N; 0 disables
  ## timing for deterministic equivalence tests or intentionally unlimited builds.

static:
  doAssert MatterTimeLimitMs >= 0, "matterTimeLimitMs must be non-negative"

type
  MatterColorCategory* = enum
    mccDefault
    mccComment
    mccString
    mccNumber
    mccBoolean
    mccKeyword
    mccOperator
    mccPreprocessor
    mccFunction
    mccType
    mccBuiltin
    mccIdentifier
    mccProperty

  MatterSpan* = object ## Half-open UTF-8 byte range in the original input line.
    firstByte*, lastByte*: int
    scopes*: seq[string]
    category*: MatterColorCategory

  MatterGrammarSource* = object
    ## One caller-owned TextMate grammar. `path` selects JSON (`.json`) versus
    ## XML plist parsing and is used in diagnostics; Moe never reads it here.
    content*: string
    path*: string
    language*: SourceLanguage
      ## An optional compatibility binding for Moe's built-in language enum.
    fileTypes*: seq[string]
      ## Additional file names or suffixes selecting this grammar. These are
      ## additive to the TextMate grammar's own `fileTypes` metadata.

  MatterGrammarSet* = ref object
    ## An immutable-by-convention collection shared by an editor's buffers.
    ## Use `withMatterGrammar` to derive a set with a programmatic override.
    sources: seq[MatterGrammarSource]
    registry: Registry
    scopes: HashSet[string]
    languageScopes: Table[SourceLanguage, string]
    fileTypeScopes: Table[string, string]
    grammarCache: Table[string, Grammar]
    unavailableScopes: HashSet[string]

  MatterLineState* = object
    ## Completed state entering the next line. A failure is sticky so a slow
    ## or invalid grammar cannot be retried on every subsequent line/frame.
    grammar: Grammar
    stack*: StateStack
    failed*: bool

proc `==`*(a, b: MatterLineState): bool =
  a.failed == b.failed and a.grammar == b.grammar and a.stack == b.stack

proc `==`*(a, b: MatterGrammarSet): bool =
  ## Runtime caches do not participate in configuration value equality.
  if a.isNil or b.isNil:
    return a.isNil and b.isNil
  a.sources == b.sources

func scopeMatches(scope, prefix: string): bool =
  scope == prefix or scope.startsWith(prefix & ".")

proc isMatterCodeBlock*(state: MatterLineState): bool =
  ## Whether a completed Markdown state is inside a fenced or indented block.
  not state.failed and (
    state.stack.hasActiveScope("markup.fenced_code.block") or
    state.stack.hasActiveScope("markup.raw.block")
  )

proc category(scopes: openArray[string]): MatterColorCategory =
  # Keep comment captures in the comment channel so Moe can apply its own
  # configurable reserved words, even when a grammar marks TODO specially.
  for scope in scopes:
    if scope.scopeMatches("comment"):
      return mccComment
  # Prefer the most specific scope, including interpolated expressions inside
  # strings. Match scope components, not substrings in language names.
  for i in countdown(scopes.high, 0):
    let scope = scopes[i]
    if scope.scopeMatches("comment"):
      return mccComment
    if scope.scopeMatches("constant.numeric"):
      return mccNumber
    if scope.scopeMatches("constant.language") or scope.scopeMatches("constant.boolean"):
      return mccBoolean
    if scope.scopeMatches("entity.name.function"):
      return mccFunction
    if scope.scopeMatches("variable.other.property") or
        scope.scopeMatches("support.type.property-name") or
        scope.scopeMatches("string.quoted.double.json") and
        "meta.structure.dictionary.key.json" in scopes:
      return mccProperty
    if scope.scopeMatches("entity.name.type") or scope.scopeMatches("support.type"):
      return mccType
    if scope.scopeMatches("entity.name.section") or scope.scopeMatches("markup.heading"):
      return mccBuiltin
    if scope.scopeMatches("keyword.operator"):
      return mccOperator
    if scope.scopeMatches("meta.preprocessor") or
        scope.scopeMatches("keyword.control.directive"):
      return mccPreprocessor
    if scope.scopeMatches("keyword") or scope.scopeMatches("storage"):
      return mccKeyword
    if scope.scopeMatches("support.function") or scope.scopeMatches("support.class"):
      return mccBuiltin
    if scope.scopeMatches("variable"):
      return mccIdentifier
    if scope.scopeMatches("string") or scope.scopeMatches("markup.inline.raw"):
      return mccString
  mccDefault

proc scopeFor(language: SourceLanguage): string =
  if language in {langNone, langDiff, langLog}:
    return ""
  let mode = ($language)[4 .. ^1].toLowerAscii
  for mapping in moeGrammarMappings:
    if mapping.modeName.toLowerAscii == mode:
      return mapping.scopeName

func normalizeFileType(fileType: string): string =
  result = fileType.toLowerAscii
  var first = 0
  while first < result.len and result[first] == '.':
    inc first
  if first == result.len:
    result.setLen(0)
  elif first > 0:
    result = result[first .. ^1]

proc scopeForFilename(grammars: MatterGrammarSet, filename: string): string =
  if grammars.isNil or filename.len == 0:
    return
  let basename = filename.extractFilename.toLowerAscii

  # A full basename is more specific than a suffix. This covers conventional
  # names such as Dockerfile while keeping suffix matching for `foo.d.ts`.
  if grammars.fileTypeScopes.hasKey(basename):
    return grammars.fileTypeScopes[basename]

  var longestMatch = -1
  for fileType, scope in grammars.fileTypeScopes.pairs:
    if basename.endsWith('.' & fileType) and fileType.len > longestMatch:
      result = scope
      longestMatch = fileType.len

proc selectedScope(
    grammars: MatterGrammarSet, language: SourceLanguage, filename: string
): string =
  if grammars.isNil or language in {langDiff, langLog}:
    return
  if grammars.languageScopes.hasKey(language):
    return grammars.languageScopes[language]
  if language != langNone:
    let inferred = scopeFor(language)
    if inferred in grammars.scopes:
      return inferred
  grammars.scopeForFilename(filename)

proc newMatterGrammarSet*(): MatterGrammarSet =
  ## Create an empty set. An empty set cannot select Matter highlighting.
  MatterGrammarSet(
    registry: newRegistry(),
    scopes: initHashSet[string](),
    languageScopes: initTable[SourceLanguage, string](),
    fileTypeScopes: initTable[string, string](),
    grammarCache: initTable[string, Grammar](),
    unavailableScopes: initHashSet[string](),
  )

proc newMatterGrammarSet*(sources: openArray[MatterGrammarSource]): MatterGrammarSet =
  ## Parse and register caller-provided grammar text. All sources are added
  ## before any root is compiled, so they may provide external includes for
  ## one another. Parse errors are reported to the caller.
  result = newMatterGrammarSet()
  for source in sources:
    let path = if source.path.len > 0: source.path else: "grammar.tmLanguage.json"
    let raw =
      try:
        parseRawGrammar(source.content, path)
      except CatchableError as error:
        raise newException(TextMateGrammarError, error.msg)
    try:
      result.registry.addGrammar(raw)
    except CatchableError as error:
      raise newException(TextMateGrammarError, error.msg)
    result.scopes.incl(raw.scopeName)
    result.sources.add(
      MatterGrammarSource(
        content: source.content,
        path: path,
        language: source.language,
        fileTypes: source.fileTypes,
      )
    )
    if source.language != langNone:
      result.languageScopes[source.language] = raw.scopeName

    for fileType in raw.fileTypes & source.fileTypes:
      let normalized = fileType.normalizeFileType
      # Earlier sources win collisions, making caller order deterministic and
      # preventing a support grammar from displacing a primary grammar later.
      if normalized.len > 0 and not result.fileTypeScopes.hasKey(normalized):
        result.fileTypeScopes[normalized] = raw.scopeName

proc grammarForScope(grammars: MatterGrammarSet, scope: string): Grammar =
  if grammars.isNil or scope.len == 0 or scope notin grammars.scopes or
      scope in grammars.unavailableScopes:
    return nil
  if grammars.grammarCache.hasKey(scope):
    return grammars.grammarCache[scope]
  try:
    result = grammars.registry.loadGrammar(scope)
    grammars.grammarCache[scope] = result
  except CatchableError as error:
    grammars.unavailableScopes.incl(scope)
    logWarn("highlight", "Matter grammar " & scope & " is unavailable: " & error.msg)

proc grammarFor(
    grammars: MatterGrammarSet, language: SourceLanguage, filename = ""
): Grammar =
  grammars.grammarForScope(grammars.selectedScope(language, filename))

proc matterSupports*(
    grammars: MatterGrammarSet, language: SourceLanguage, filename = ""
): bool =
  ## Matter is available only after this set received a valid root grammar.
  ## Diff and Log deliberately retain Moe's specialised built-in highlighters.
  not grammars.grammarFor(language, filename).isNil

proc matterSupports*(language: SourceLanguage): bool =
  ## The compatibility query has no implicit global grammar registry. Callers
  ## must pass the grammar set they opted into.
  discard language
  false

proc withMatterGrammar*(
    grammars: MatterGrammarSet,
    language: SourceLanguage,
    content: string,
    path = "grammar.tmLanguage.json",
): MatterGrammarSet =
  ## Return a grammar set with one programmatic root for `language`. Existing
  ## inferred/config-file grammars and roots for other languages are retained.
  ## The new root is compiled before return, so malformed regexes fail at the
  ## API boundary instead of silently degrading on the first rendered line.
  if language in {langNone, langDiff, langLog}:
    raise newException(
      TextMateGrammarError,
      "Matter highlighting requires a concrete non-Diff/Log language",
    )
  var sources: seq[MatterGrammarSource]
  if not grammars.isNil:
    for source in grammars.sources:
      if source.language != language:
        sources.add(source)
  sources.add(MatterGrammarSource(content: content, path: path, language: language))
  result = newMatterGrammarSet(sources)
  if result.grammarFor(language).isNil:
    raise newException(
      TextMateGrammarError, "TextMate grammar could not be compiled for " & $language
    )

proc withMatterGrammar*(
    grammars: MatterGrammarSet, source: MatterGrammarSource
): MatterGrammarSet =
  ## Return a grammar set with one dynamically selected TextMate grammar.
  ## The grammar's own `fileTypes` and `source.fileTypes` aliases select it.
  ## Its associations take precedence over the existing set, and another
  ## grammar with the same scope is replaced.
  let
    sourcePath = if source.path.len > 0: source.path else: "grammar.tmLanguage.json"
    raw = parseRawGrammar(source.content, sourcePath)
  var sources = @[source]
  if not grammars.isNil:
    for existing in grammars.sources:
      let existingRaw = parseRawGrammar(existing.content, existing.path)
      if existingRaw.scopeName != raw.scopeName:
        sources.add(existing)
  result = newMatterGrammarSet(sources)

  if result.grammarForScope(raw.scopeName).isNil:
    raise newException(
      TextMateGrammarError,
      "TextMate grammar could not be compiled for " & raw.scopeName,
    )

proc initialMatterState*(
    grammars: MatterGrammarSet, language: SourceLanguage, filename = ""
): MatterLineState =
  ## Create a fresh line state for a grammar set/language pair.
  MatterLineState(grammar: grammars.grammarFor(language, filename))

proc sanitizeInvalidUtf8(line: string): string =
  ## Replace only malformed high bytes with spaces, preserving byte positions
  ## for returned spans. The buffer's original contents are never modified.
  result = line
  var pos = 0
  while pos < result.len:
    let size = result.runeSizeAt(pos)
    if size == 1 and uint8(result[pos]) >= 0x80:
      result[pos] = ' '
    pos += size

proc tokenizeMatterLine*(
    line: string,
    language: SourceLanguage,
    previous = MatterLineState(),
    timeLimitMs = MatterTimeLimitMs,
    grammars: MatterGrammarSet = nil,
    filename = "",
): tuple[spans: seq[MatterSpan], nextState: MatterLineState] =
  ## Tokenize one line with a soft deadline (0 disables it). Failed/partial
  ## parses return no spans and no partial stack. Subsequent lines stay plain
  ## until the caller restarts from an earlier successful or fresh state.
  if previous.failed:
    result.nextState = previous
    return
  let grammar =
    if previous.grammar.isNil:
      grammars.grammarFor(language, filename)
    else:
      previous.grammar
  if grammar.isNil:
    result.nextState.failed = true
    return
  result.nextState.grammar = grammar
  try:
    let parsed =
      grammar.tokenizeLine(sanitizeInvalidUtf8(line), previous.stack, timeLimitMs)
    if parsed.stoppedEarly:
      result.nextState.failed = true
      logWarn(
        "highlight",
        "Matter tokenization exceeded its soft line budget for " & $language,
      )
      return
    result.nextState.grammar = grammar
    result.nextState.stack = parsed.completedRuleStack
    for token in parsed.tokens:
      if token.endIndex > token.startIndex:
        result.spans.add(
          MatterSpan(
            firstByte: token.startIndex,
            lastByte: token.endIndex,
            scopes: token.scopes,
            category: category(token.scopes),
          )
        )
  except CatchableError as error:
    result.nextState.failed = true
    logWarn(
      "highlight", "Matter tokenization failed for " & $language & ": " & error.msg
    )
