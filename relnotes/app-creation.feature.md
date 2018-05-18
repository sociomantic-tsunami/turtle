### Create tested application before `prepare`

Previously it was not possible to tweak automatically created tested application
object because it was still `null` when overriden `prepare` method gets run. Now
turtle will create application before `prepare` method. It will still _start_
tested application after `prepare`, same as before.
