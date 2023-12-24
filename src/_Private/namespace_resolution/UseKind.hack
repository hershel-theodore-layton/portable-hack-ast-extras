/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\_Private;

enum UseKind: int {
  CONST = 0;
  FUNCTION = 1;
  NAMESPACE = 2;
  TYPE = 3;
  NONE = 4;
}
