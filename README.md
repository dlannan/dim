# dim
lite text editor running from sokol-luajit

## Lite

This project would not exist without lite:

https://github.com/rxi/lite/tree/master

Lite is a brilliant simple lightweight text editor written in lua. And supports plugins and more.

Being written in Lua it means that it can work with sokol-luajit that I have put together. The benefits here means there is nothing to build (unless you want to pack it into a simple bundle :) ) and the platforms can be varied - It should initially work on Win, OSX and Linux without too many problems.

I also expect it should be able to be built for Android and IOS as well with some extra work. 

The intended use for this will be in the sokol-luajit editor (Thunc). It will allow the easy editing, loading, saving of game engine scripts. Debugging should also be able to be added (future goal).
