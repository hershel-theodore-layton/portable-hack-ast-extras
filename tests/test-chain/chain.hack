/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Project_qkfwww9J6CQJ\GeneratedTestChain;

use namespace HTL\TestChain;
use type HTL\Pragma\Pragmas;

<<file: Pragmas(vec['PhaLinters', 'digest:f02eabac84d0ecd43e8f'])>>

async function tests_async(
  TestChain\ChainController<\HTL\TestChain\Chain> $controller,
)[defaults]: Awaitable<TestChain\ChainController<\HTL\TestChain\Chain>> {
  return $controller
    ->addTestGroup(\HTL\Pha\Tests\pragma_scope_test<>)
    ->addTestGroup(\HTL\Pha\Tests\resolve_test<>)
    ->addTestGroup(\HTL\Pha\Tests\resolve_v2_test<>);
}
