# [develop](https://github.com/adhearsion/has-guarded-handlers)
  * Feature: Add a broadcast mode to handler triggering, which ignores what happens in handlers (return value and exceptions) and unconditionally continues the handler chain.

# [1.5.0](https://github.com/adhearsion/has-guarded-handlers/compare/v1.4.2...v1.5.0) - [2012-12-08](https://rubygems.org/gems/has-guarded-handlers/versions/1.5.0)
  * Bugfix: Correct API preservation from previous release

# [1.4.2](https://github.com/adhearsion/has-guarded-handlers/compare/v1.4.1...v1.4.2) - [2012-12-08](https://rubygems.org/gems/has-guarded-handlers/versions/1.4.2)
  * Bugfix: Preserve the old 'API' by which handlers were called

# [1.4.1](https://github.com/adhearsion/has-guarded-handlers/compare/v1.4.0...v1.4.1) - [2012-12-08](https://rubygems.org/gems/has-guarded-handlers/versions/1.4.1)
  * Bugfix: Report handler execution correctly in edge cases

# [1.4.0](https://github.com/adhearsion/has-guarded-handlers/compare/v1.3.1...v1.4.0) - [2012-12-08](https://rubygems.org/gems/has-guarded-handlers/versions/1.4.0)
  * Feature: Return true/false from #trigger_handler depending on wether a handler was called or not

# [1.3.1](https://github.com/adhearsion/has-guarded-handlers/compare/v1.3.0...v1.3.1) - [2012-07-19](https://rubygems.org/gems/has-guarded-handlers/versions/1.3.1)
  * Removed dependency on uuid gem in favour of the Ruby built-in `SecureRandom.uuid`

# [1.3.0](https://github.com/adhearsion/has-guarded-handlers/compare/v1.2.0...v1.3.0) - [2012-07-03](https://rubygems.org/gems/has-guarded-handlers/versions/1.3.0)
  * Feature: It is now possible to register a handler to process all events
  * Bugfix: Temporary handlers were being removed after the first event even if their guards didn't match
  * Bugfix: Fix for a syntax error on Ruby 1.8

# [1.2.0](https://github.com/adhearsion/has-guarded-handlers/compare/v1.1.0...v1.2.0) - [2012-03-28](https://rubygems.org/gems/has-guarded-handlers/versions/1.2.0)
  * Feature: Allow registering temporary (single execution) handlers which are removed after they are triggered
  * Feature: Registering a handler returns an ID by which it may be unregistered

# [1.1.0](https://github.com/adhearsion/has-guarded-handlers/compare/v1.0.0...v1.1.0) - [2012-01-21](https://rubygems.org/gems/has-guarded-handlers/versions/1.1.0)
  * Feature: Allow guarding on the value of method calls with arguments, by using an array as a hash key

# [1.0.0](https://github.com/adhearsion/has-guarded-handlers/compare/v0.0.1...v1.0.0) - [2012-01-19](https://rubygems.org/gems/has-guarded-handlers/versions/1.0.0)
  * Bump to 1.0.0 because the API is stable
  * Feature: Allow guarding with a module to test if an object has a mixin

# 0.1.1
  * Bugfix: Fix an exception when triggering an event when no handlers are set

# 0.1.0
  * Allow setting a priority with which to execute a handler, where higher priority handlers are exectuted first

# 0.0.3
  * Allow classes to be passed as guards, matching against an event via #is_a?

# 0.0.2
  * Bugfix: The mixin now does not hijack the target's initializer which was causing issues with inheritance

# 0.0.1
  * Feature: Some code that works!
