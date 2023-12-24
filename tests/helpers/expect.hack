/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\Tests;

use type Facebook\HackTest\ExpectationFailedException;
use namespace HH\Lib\{Str, Vec};
use namespace HTL\Pha;

/**
 * This is not fbexpect!
 *
 * This function and the returned object are annotated with coeffects.
 * This expect-lib allows for pure test methods in HackTest.
 */
function expect<T>(T $value)[]: ExpectObj<T> {
  return new ExpectObj($value);
}

final class ExpectObj<T> {
  public function __construct(private T $value)[] {}

  public function toBeNil()[]: void where T as Pha\NillableNode {
    $this->toEqual(Pha\NIL);
  }

  public function toEqual(mixed $other)[]: void {
    if ($this->value === $other) {
      return;
    }

    static::fail(
      "Expected `a === b`, but got:\n - %s\n - %s",
      static::serializeValue($this->value),
      static::serializeValue($other),
    );
  }

  public function toReturn()[]: void where T as (function()[]: mixed) {
    try {
      ($this->value)();
    } catch (Pha\PhaException $e) {
      static::fail(
        'Expected a value return, got a throw: %s',
        $e->getMessage(),
      );
    }
  }

  public function toThrowPhaException(string $pattern)[]: void
  where
    T as (function()[]: mixed) {
    try {
      ($this->value)();
      static::fail('Expected a PhaException, got none');
    } catch (Pha\PhaException $e) {
      // Implement some nice patterns later.
      if (!Str\contains($e->getMessage(), $pattern)) {
        static::fail(
          "Did not see the excepted pattern:\n - '%s'\n - '%s'",
          $pattern,
          $e->getMessage(),
        );
      }
    }
  }

  /**
   * This implements a knock-off json encoding with hex encoded integers.
   * Reason being, hhvm 4.102 doesn't support json_encode_pure.
   */
  private static function serializeValue(mixed $value)[]: string {
    if ($value is null) {
      return 'null';
    }

    if ($value === true) {
      return 'true';
    }

    if ($value === false) {
      return 'false';
    }

    if ($value is int) {
      return Str\format('%d (%016x)', $value, $value);
    }

    if ($value is string) {
      return static::stringExportPure($value);
    }

    if ($value is vec<_>) {
      return Str\format(
        '[%s]',
        Vec\map($value, static::serializeValue<>) |> Str\join($$, ', '),
      );
    }

    invariant_violation('Sorry, I can not show you a diff...');
  }

  /**
   * @see https://github.com/hershel-theodore-layton/static-type-assertion-code-generator/blob/master/src/_Private/string_export.hack
   */
  private static function stringExportPure(string $string)[]: string {
    return Str\replace_every($string, dict['\\' => '\\\\', "'" => "\'"])
      |> "'".$$."'";
  }

  private static function fail(
    Str\SprintfFormatString $format,
    mixed ...$args
  )[]: nothing {
    throw new ExpectationFailedException(\vsprintf($format, $args));
  }
}
