/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha;

final class NameResolution {
  private function __construct(
    private string $name,
    private ResolverNameKind $kind,
    private TypeDependency $dependency,
    private NillableSyntax $typeParameter,
    private NillableSyntax $useClause,
  )[] {}

  public static function create(
    string $name,
    ResolverNameKind $kind,
    TypeDependency $dependency,
    NillableSyntax $type_parameter,
    NillableSyntax $use_clause,
  )[]: NameResolution {
    return new self($name, $kind, $dependency, $type_parameter, $use_clause);
  }

  public function getName()[]: string {
    return $this->name;
  }

  public function getKind()[]: ResolverNameKind {
    return $this->kind;
  }

  public function getDependency()[]: TypeDependency {
    return $this->dependency;
  }

  public function getTypeParameter()[]: NillableSyntax {
    return $this->typeParameter;
  }

  public function getUseClause()[]: NillableSyntax {
    return $this->useClause;
  }
}
