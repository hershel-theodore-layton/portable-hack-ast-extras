/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha;

function resolve_name(
  Resolver $resolver,
  Script $script,
  NillableNode $node,
)[]: string {
  return resolve_name_and_use_clause($resolver, $script, $node)[0];
}

function resolve_name_and_use_clause(
  Resolver $resolver,
  Script $script,
  NillableNode $node,
)[]: (string, NillableSyntax) {
  if ($node === NIL) {
    return tuple('', NIL);
  }

  return _Private\resolver_reveal($resolver)->resolveName(
    _Private\cast_away_nil($node),
    node_get_syntax_ancestors($script, $node),
    node_get_code_compressed($script, $node),
  );
}
