# portable-hack-ast-extras

_Extra utilities for use with portable-hack-ast._

### Why this repo?

_Why is this not part of portable-hack-ast?_

Portable Hack AST should rarely need new feature updates.
Chances are small, but not zero, that the AST has a breaking change.
This would mean that portable-hack-ast would have two incompatible versions.

Since upgrading to hhvm 6.33+ requires a lot of effort,
I don't want features to become exclusive to the latest version.
By giving accessories like this a home in this repository,
I assure myself I have a place to add "extras" which can be used regardless your hhvm version.
