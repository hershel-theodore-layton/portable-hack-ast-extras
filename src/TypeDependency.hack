/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha;

/** The lexical root on which a type name depends. */
enum TypeDependency: int {
  NONE = 0;
  TYPE_PARAMETER = 1;
  THIS = 2;
  SELF = 3;
  STATIC = 4;
}
