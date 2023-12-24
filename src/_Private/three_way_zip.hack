/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\_Private;

use namespace HH\Lib\{C, Math};

function three_way_zip<T1, T2, T3>(
  Traversable<T1> $first,
  Traversable<T2> $second,
  Traversable<T3> $third,
)[]: vec<(T1, T2, T3)> {
  $one = vec($first);
  $two = vec($second);
  $three = vec($third);

  $result = vec[];
  $lesser_count = Math\minva(C\count($one), C\count($two), C\count($three));

  for ($i = 0; $i < $lesser_count; ++$i) {
    $result[] = tuple($one[$i], $two[$i], $three[$i]);
  }

  return $result;
}
