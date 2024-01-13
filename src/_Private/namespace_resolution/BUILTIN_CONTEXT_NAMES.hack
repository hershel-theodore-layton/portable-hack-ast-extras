/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha\_Private;

// @see https://github.com/facebook/hhvm/blob/09f6283fcdbdac9b4ec19768d809ee7d2012e612/hphp/hack/src/parser/hh_autoimport.ml
const vec<string> BUILTIN_CONTEXT_NAMES = vec[
  'defaults',
  'write_props',
  'leak_safe',
  'leak_safe_shallow',
  'leak_safe_local',
  'zoned',
  'zoned_shallow',
  'zoned_local',
  'zoned_with',
  'read_globals',
  'globals',
  'rx',
  'rx_shallow',
  'rx_local',
];
