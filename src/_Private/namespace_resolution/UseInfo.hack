/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\_Private;

use namespace HTL\Pha;

final class UseInfo {
  public function __construct(
    private UseKind $kind,
    private Pha\Syntax $clause,
    private string $prefix,
    private string $localName,
    private string $preAliasName,
  )[] {}

  public function getClause()[]: Pha\Syntax {
    return $this->clause;
  }

  public function getKind()[]: UseKind {
    return $this->kind;
  }

  public function getLocalName()[]: string {
    return $this->localName;
  }

  public function getPreAliasName()[]: string {
    return $this->preAliasName;
  }

  public function getPrefix()[]: string {
    return $this->prefix;
  }
}
