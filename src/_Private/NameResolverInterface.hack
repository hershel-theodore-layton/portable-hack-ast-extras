/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\_Private;

use namespace HTL\Pha;

interface NameResolverInterface {
  public function bubbleQualifiedName(
    Pha\Node $name,
    vec<Pha\Syntax> $ancestors,
  )[]: Pha\Node;

  public function resolveNameInContext(
    Pha\NillableNode $name,
    vec<Pha\Syntax> $ancestors,
    string $compressed_code,
  )[]: Pha\NameResolution;

  public function resolveName(
    Pha\Node $name,
    vec<Pha\Syntax> $ancestors,
    string $compressed_code,
  )[]: (string, NillableSyntax);
}
