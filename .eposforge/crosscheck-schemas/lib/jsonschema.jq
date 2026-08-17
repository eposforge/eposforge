# jsonschema.jq — minimal JSON Schema (2020-12 subset) validator in pure jq.
#
# Why this exists: the cross-check contract has to be checkable by any agent CLI
# on any host, with no language runtime beyond bash + jq. A full validator is not
# needed; the schemas in this directory deliberately use only the subset below.
#
# Supported keywords:
#   $ref (local "#/$defs/..." only), type, enum, const, pattern, minLength,
#   maxLength, minimum, maximum, required, properties,
#   additionalProperties:false, items, minItems, uniqueItems, allOf, anyOf,
#   if/then/else
#
# NOT supported (do not use them in the schemas here): $ref to another file,
# patternProperties, dependentSchemas, oneOf, not, prefixItems, $dynamicRef.
#
# Entry points:
#   jsonschema_errors($schema)        -> [ "path: message", ... ]   (human)
#   jsonschema_error_objects($schema) -> [ {path,pointer,keyword,   (machine)
#                                           property?,message}, ... ]
# Empty array means valid.
#
# ONE SOURCE, TWO RENDERINGS (eposforge:EF-079). `_validate` emits objects, and
# the human strings are rendered FROM those objects — they are not produced
# independently and then kept in step by hand. That is deliberate and it is the
# whole safety argument: a caller acting on the machine form can never be acting
# on a different set of errors than a human reading the text, so the machine
# channel cannot become a way to accept a payload the human form rejects. If you
# add a keyword, add it once, as an object; the string follows for free.
#
# `pointer` is RFC 6901 and is threaded through the recursion rather than parsed
# back out of `path` at the end. Deriving it by string-munging `$.a[0].b` would
# have to guess how to split a key containing `.` or `[`; carrying it is exact.

def _jtype:
  if . == null then "null"
  elif type == "number" then (if . == floor then "integer" else "number" end)
  else type
  end;

def _typeok($t):
  (_jtype) as $a
  | if $t == "number" then ($a == "number" or $a == "integer")
    else $a == $t
    end;

def _resolve($root; $sch):
  if ($sch | type) == "object" and ($sch | has("$ref"))
  then ($root | getpath($sch["$ref"] | ltrimstr("#/") | split("/")))
  else $sch
  end;

# RFC 6901 segment escaping: `~` -> `~0` first, then `/` -> `~1`. Order matters —
# doing it the other way round would re-escape the tildes this step introduces.
def _ptrseg: tostring | gsub("~"; "~0") | gsub("/"; "~1");

# The only place an error is constructed.
def _err($path; $ptr; $keyword; $message):
  { path: $path, pointer: $ptr, keyword: $keyword, message: $message };

def _validate($root; $schema; $data; $path; $ptr):
  (_resolve($root; $schema)) as $sch
  | if ($sch | type) == "boolean"
    then (if $sch then []
          else [_err($path; $ptr; "schema"; "schema forbids any value")] end)
    else
      (
        if ($sch | has("type"))
        then ($sch.type) as $t
          | if ($t | type) == "array"
            then (if any($t[]; . as $x | $data | _typeok($x))
                  then []
                  else [_err($path; $ptr; "type"; "expected \($t | join("|")), got \($data | _jtype)")]
                  end)
            else (if ($data | _typeok($t))
                  then []
                  else [_err($path; $ptr; "type"; "expected \($t), got \($data | _jtype)")]
                  end)
            end
        else []
        end
      ) as $terr
      | if ($terr | length) > 0
        then $terr
        else
            ( if ($sch | has("enum"))
              then (if ($sch.enum | index($data)) != null then []
                    else [_err($path; $ptr; "enum"; "\($data | tojson) is not one of \($sch.enum | tojson)")] end)
              else [] end )
          + ( if ($sch | has("const"))
              then (if $data == $sch.const then []
                    else [_err($path; $ptr; "const"; "must equal \($sch.const | tojson)")] end)
              else [] end )
          + ( if ($sch | has("pattern")) and (($data | type) == "string")
              then (if ($data | test($sch.pattern)) then []
                    else [_err($path; $ptr; "pattern"; "does not match /\($sch.pattern)/")] end)
              else [] end )
          + ( if ($sch | has("minLength")) and (($data | type) == "string")
              then (if ($data | length) >= $sch.minLength then []
                    else [_err($path; $ptr; "minLength"; "shorter than minLength \($sch.minLength)")] end)
              else [] end )
          + ( if ($sch | has("maxLength")) and (($data | type) == "string")
              then (if ($data | length) <= $sch.maxLength then []
                    else [_err($path; $ptr; "maxLength"; "longer than maxLength \($sch.maxLength)")] end)
              else [] end )
          + ( if ($sch | has("minimum")) and (($data | type) == "number")
              then (if $data >= $sch.minimum then []
                    else [_err($path; $ptr; "minimum"; "\($data) is below minimum \($sch.minimum)")] end)
              else [] end )
          + ( if ($sch | has("maximum")) and (($data | type) == "number")
              then (if $data <= $sch.maximum then []
                    else [_err($path; $ptr; "maximum"; "\($data) is above maximum \($sch.maximum)")] end)
              else [] end )
          + ( if ($data | type) == "object"
              then
                  # `property` is carried as its own field here and below. That is
                  # the point of EF-079: a caller recovering the offending key must
                  # not have to unquote it out of an English sentence.
                  ( ($sch.required // [])
                    | map(. as $k | if ($data | has($k)) then empty
                                    else (_err($path; $ptr; "required"; "missing required property \"\($k)\"")
                                          + {property: $k}) end) )
                + ( if ($sch | has("properties"))
                    then [ $sch.properties | to_entries[] as $e
                           | select($data | has($e.key))
                           | _validate($root; $e.value; $data[$e.key]; "\($path).\($e.key)"; "\($ptr)/\($e.key | _ptrseg)") ]
                         | add // []
                    else [] end )
                + ( if ($sch.additionalProperties == false)
                    then [ ($sch.properties // {}) as $props
                           | $data | keys[] as $k
                           | select(($props | has($k)) | not)
                           | (_err($path; $ptr; "additionalProperties"; "unexpected property \"\($k)\"")
                              + {property: $k}) ]
                    else [] end )
              else [] end )
          + ( if ($data | type) == "array"
              then
                  ( if ($sch | has("items"))
                    then [ range(0; $data | length) as $i
                           | _validate($root; $sch.items; $data[$i]; "\($path)[\($i)]"; "\($ptr)/\($i)") ]
                         | add // []
                    else [] end )
                + ( if ($sch | has("minItems"))
                    then (if ($data | length) >= $sch.minItems then []
                          else [_err($path; $ptr; "minItems"; "needs at least \($sch.minItems) item(s)")] end)
                    else [] end )
                + ( if ($sch.uniqueItems == true)
                    then (if (($data | unique | length) == ($data | length)) then []
                          else [_err($path; $ptr; "uniqueItems"; "items are not unique")] end)
                    else [] end )
              else [] end )
          + ( if ($sch | has("allOf"))
              then [ $sch.allOf[] as $s | _validate($root; $s; $data; $path; $ptr) ] | add // []
              else [] end )
          + ( if ($sch | has("anyOf"))
              then (if any($sch.anyOf[]; . as $s | (_validate($root; $s; $data; $path; $ptr) | length) == 0)
                    then []
                    else [_err($path; $ptr; "anyOf"; "matches none of the allowed shapes")] end)
              else [] end )
          + ( if ($sch | has("if"))
              then (if (_validate($root; $sch["if"]; $data; $path; $ptr) | length) == 0
                    then (if ($sch | has("then")) then _validate($root; $sch["then"]; $data; $path; $ptr) else [] end)
                    else (if ($sch | has("else")) then _validate($root; $sch["else"]; $data; $path; $ptr) else [] end)
                    end)
              else [] end )
        end
    end;

# `.` is the instance document; $schema is the schema document.
# The root pointer is "" (RFC 6901's whole-document pointer), not "/".
def jsonschema_error_objects($schema): _validate($schema; $schema; .; "$"; "");

# The human rendering, derived from the objects above. Byte-identical to what
# this library emitted before EF-079 — callers parsing this text keep working,
# which is the point of adding a channel rather than replacing one.
def jsonschema_errors($schema):
  jsonschema_error_objects($schema) | map("\(.path): \(.message)");
