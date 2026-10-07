/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Project_qkfwww9J6CQJ\GeneratedTestChain;

use namespace HTL\TestChain;
use type HTL\Pragma\Pragmas;

<<file: Pragmas(vec['PhaLinters', 'digest:cb68a6ba5f04e6e47d82'])>>

async function tests_async(
  TestChain\ChainController<\HTL\TestChain\Chain> $controller,
)[defaults]: Awaitable<TestChain\ChainController<\HTL\TestChain\Chain>> {
  return $controller
    ->addTestGroup(\HTL\Pha\Tests\resolve_test<>)
    ->addTestGroup(\HTL\Pha\Tests\resolve_v2_test<>);
}
