# budget.sh — one definition of what a payload costs. Source, do not execute.
#
# Anything that grows a payload must call refresh_budget on it. Coverage and
# check results are appended after the author stops writing, so a budget
# recorded at authoring time is stale exactly when it matters.
#
# The token estimate is bytes/4 and is deliberately crude — it exists to decide
# "is this payload out of hand", not to bill anyone. Validation measures the
# file rather than trusting the field, so a stale or optimistic budget cannot
# buy anything.

# refresh_budget <payload-file> <cap>
# Rewrites .budget in place. Prints a warning to stderr when over cap.
refresh_budget() {
  local file="$1" cap="$2"
  local bytes tokens over prev=""
  # Writing the budget changes the size the budget describes, so iterate until
  # it settles. Two passes is always enough; three is paranoia that costs
  # nothing.
  for _ in 1 2 3; do
    bytes="$(wc -c <"$file" | tr -d ' ')"
    [[ "$bytes" == "$prev" ]] && break
    prev="$bytes"
    tokens=$(( bytes / 4 ))
    over=false
    (( tokens > cap )) && over=true
    jq --argjson b "$bytes" --argjson t "$tokens" --argjson c "$cap" --argjson o "$over" \
       '.budget = {est_tokens: $t, rendered_bytes: $b, cap: $c, over_budget: $o}' \
       "$file" > "$file.budget.tmp" || return 1
    mv "$file.budget.tmp" "$file"
  done
  if [[ "$over" == "true" ]]; then
    echo "budget: ${tokens} tok exceeds cap ${cap} — trim before handoff; transport will refuse it" >&2
  fi
  return 0
}
