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
# Entry point:  jsonschema_errors($schema)  ->  [ "path: message", ... ]
# Empty array means valid.

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

def _validate($root; $schema; $data; $path):
  (_resolve($root; $schema)) as $sch
  | if ($sch | type) == "boolean"
    then (if $sch then [] else ["\($path): schema forbids any value"] end)
    else
      (
        if ($sch | has("type"))
        then ($sch.type) as $t
          | if ($t | type) == "array"
            then (if any($t[]; . as $x | $data | _typeok($x))
                  then []
                  else ["\($path): expected \($t | join("|")), got \($data | _jtype)"]
                  end)
            else (if ($data | _typeok($t))
                  then []
                  else ["\($path): expected \($t), got \($data | _jtype)"]
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
                    else ["\($path): \($data | tojson) is not one of \($sch.enum | tojson)"] end)
              else [] end )
          + ( if ($sch | has("const"))
              then (if $data == $sch.const then []
                    else ["\($path): must equal \($sch.const | tojson)"] end)
              else [] end )
          + ( if ($sch | has("pattern")) and (($data | type) == "string")
              then (if ($data | test($sch.pattern)) then []
                    else ["\($path): does not match /\($sch.pattern)/"] end)
              else [] end )
          + ( if ($sch | has("minLength")) and (($data | type) == "string")
              then (if ($data | length) >= $sch.minLength then []
                    else ["\($path): shorter than minLength \($sch.minLength)"] end)
              else [] end )
          + ( if ($sch | has("maxLength")) and (($data | type) == "string")
              then (if ($data | length) <= $sch.maxLength then []
                    else ["\($path): longer than maxLength \($sch.maxLength)"] end)
              else [] end )
          + ( if ($sch | has("minimum")) and (($data | type) == "number")
              then (if $data >= $sch.minimum then []
                    else ["\($path): \($data) is below minimum \($sch.minimum)"] end)
              else [] end )
          + ( if ($sch | has("maximum")) and (($data | type) == "number")
              then (if $data <= $sch.maximum then []
                    else ["\($path): \($data) is above maximum \($sch.maximum)"] end)
              else [] end )
          + ( if ($data | type) == "object"
              then
                  ( ($sch.required // [])
                    | map(. as $k | if ($data | has($k)) then empty
                                    else "\($path): missing required property \"\($k)\"" end) )
                + ( if ($sch | has("properties"))
                    then [ $sch.properties | to_entries[] as $e
                           | select($data | has($e.key))
                           | _validate($root; $e.value; $data[$e.key]; "\($path).\($e.key)") ]
                         | add // []
                    else [] end )
                + ( if ($sch.additionalProperties == false)
                    then [ ($sch.properties // {}) as $props
                           | $data | keys[] as $k
                           | select(($props | has($k)) | not)
                           | "\($path): unexpected property \"\($k)\"" ]
                    else [] end )
              else [] end )
          + ( if ($data | type) == "array"
              then
                  ( if ($sch | has("items"))
                    then [ range(0; $data | length) as $i
                           | _validate($root; $sch.items; $data[$i]; "\($path)[\($i)]") ]
                         | add // []
                    else [] end )
                + ( if ($sch | has("minItems"))
                    then (if ($data | length) >= $sch.minItems then []
                          else ["\($path): needs at least \($sch.minItems) item(s)"] end)
                    else [] end )
                + ( if ($sch.uniqueItems == true)
                    then (if (($data | unique | length) == ($data | length)) then []
                          else ["\($path): items are not unique"] end)
                    else [] end )
              else [] end )
          + ( if ($sch | has("allOf"))
              then [ $sch.allOf[] as $s | _validate($root; $s; $data; $path) ] | add // []
              else [] end )
          + ( if ($sch | has("anyOf"))
              then (if any($sch.anyOf[]; . as $s | (_validate($root; $s; $data; $path) | length) == 0)
                    then []
                    else ["\($path): matches none of the allowed shapes"] end)
              else [] end )
          + ( if ($sch | has("if"))
              then (if (_validate($root; $sch["if"]; $data; $path) | length) == 0
                    then (if ($sch | has("then")) then _validate($root; $sch["then"]; $data; $path) else [] end)
                    else (if ($sch | has("else")) then _validate($root; $sch["else"]; $data; $path) else [] end)
                    end)
              else [] end )
        end
    end;

# `.` is the instance document; $schema is the schema document.
def jsonschema_errors($schema): _validate($schema; $schema; .; "$");
