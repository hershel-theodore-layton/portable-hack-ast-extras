/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha;

/**
 * @param $node must a name token, a part of a qualified name, or NIL.
 * @throws If $node is none of the kinds listed above.
 */
function resolve_name(
  Resolver $resolver,
  Script $script,
  NillableNode $node,
)[]: string {
  return resolve_name_and_use_clause($resolver, $script, $node)[0];
}

/**
 * @param $node must a name token, a qualified name, or NIL.
 * @throws If $node is none of the kinds listed above.
 */
function resolve_name_and_use_clause(
  Resolver $resolver,
  Script $script,
  NillableNode $node,
)[]: (string, NillableSyntax) {
  if ($node === NIL) {
    return tuple('', NIL);
  }

  $node = _Private\cast_away_nil($node);

  return _Private\resolver_reveal($resolver)->resolveName(
    $node,
    node_get_syntax_ancestors($script, $node),
    node_get_code_compressed($script, $node),
    node_get_kind($script, $node),
  );
}
