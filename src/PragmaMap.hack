/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha;

use namespace HH\Lib\Vec;

final class PragmaMap {
  public function __construct(
    private vec<(Syntax, LineAndColumnNumbers, vec<string>)> $pragmas,
  )[] {}

  public function getOverlappingPragmas(
    LineAndColumnNumbers $target,
  )[]: vec<vec<string>> {
    return Vec\filter(
      $this->pragmas,
      $t ==> $target->getEndLine() >= $t[1]->getStartLine() &&
        $target->getStartLine() <= $t[1]->getEndLine(),
    )
      |> Vec\map($$, $t ==> $t[2]);
  }

  public function getAllPragmas(
  )[]: vec<(Syntax, LineAndColumnNumbers, vec<string>)> {
    return $this->pragmas;
  }
}
