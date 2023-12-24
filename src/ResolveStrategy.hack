/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha;

enum ResolveStrategy: int {
  /**
   * Look at the casing of a type.
   * snake_case -> assume function
   * SHOUT_CAUSE -> assume const
   * PascalCase -> assume type.
   * `_` -> assume type
   * `__...` -> assume built-in attribute or constant
   */
  JUST_GUESS = 0;
}
