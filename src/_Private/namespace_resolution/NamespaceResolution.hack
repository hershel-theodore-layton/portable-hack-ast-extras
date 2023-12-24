/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\_Private;

use namespace HTL\Pha;

final class NamespaceResolution {
  private NodeId $startsAt;
  private NodeId $endsAt;

  public function __construct(
    Pha\Syntax $starts_at,
    Pha\Node $ends_at,
    private string $name,
    private dict<UseKind, vec<UseInfo>> $uses,
    private ?NamespaceResolution $parent,
  )[] {
    $this->startsAt = node_get_id($starts_at);
    $this->endsAt = node_get_id($ends_at);
  }

  public function getName()[]: string {
    return $this->parent is null
      ? $this->name
      : $this->parent->getName().$this->name;
  }

  public function getParent()[]: ?NamespaceResolution {
    return $this->parent;
  }

  public function getUses()[]: dict<UseKind, vec<UseInfo>> {
    return $this->uses;
  }

  public function isInRange(Pha\Node $node)[]: bool {
    return
      node_is_between_or_at_boundary($node, $this->startsAt, $this->endsAt);
  }
}
