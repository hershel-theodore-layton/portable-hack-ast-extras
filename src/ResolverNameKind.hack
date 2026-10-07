/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha;

/** The syntactic role of the name, independent of its import kind. */
enum ResolverNameKind: int {
  TYPE = 0;
  FUNCTION = 1;
  CONST = 2;
  NAMESPACE = 3;
  MEMBER = 4;
  ATTRIBUTE = 5;
  CONTEXT = 6;
  UNKNOWN = 7;
}
