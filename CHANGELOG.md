# develop
  * Feature: Allow registering temporary (single execution) handlers which are removed after they are triggered
  * Feature: Registering a handler returns an ID by which it may be unregistered

# 1.1.0 - 2012-01-21
  * Feature: Allow guarding on the value of method calls with arguments, by using an array as a hash key

# 1.0.0 - 2012-01-19
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
