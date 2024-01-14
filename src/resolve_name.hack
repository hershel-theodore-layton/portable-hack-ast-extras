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

  $node = _Private\cast_away_nil($node);

  $resolver = _Private\resolver_reveal($resolver);
  $ancestors = node_get_syntax_ancestors($script, $node);
  $node = $resolver->bubbleQualifiedName($node, $ancestors);
  $compressed_code = node_get_code_compressed($script, $node);

  return $resolver->resolveName($node, $ancestors, $compressed_code);
}
