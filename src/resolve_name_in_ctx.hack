/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha;

/** Resolves a name with lexical information. Requires the v2 resolver. */
function resolve_name_in_ctx(
  Resolver $resolver,
  Script $script,
  NillableNode $node,
)[]: NameResolution {
  $implementation = _Private\resolver_reveal($resolver);
  if ($node === NIL) {
    // This can be removed once the old Resolver implementation is removed.
    // It exists to throw on the old one instead of returning a known value.
    return $implementation->resolveNameInContext(NIL, vec[], '');
  }
  $node = _Private\cast_away_nil($node);
  $ancestors = node_get_syntax_ancestors($script, $node);
  $node = $implementation->bubbleQualifiedName($node, $ancestors);
  return $implementation->resolveNameInContext(
    $node,
    $ancestors,
    node_get_code_compressed($script, $node),
  );
}
