# dim
not so lite 

A lite based text editor running from sokol-luajit + nuklear.

[ 23-10-2025 Updates already ]:

- Its working. Most (if not all?) of lite's operations are working. Theres a couple of system calls that result in "File Not Found" in the console - this is due to .. and . being included in the file list. Will fix. 
- Added an image view plugin (see pic below)
- Adding a gltf 3D viewer as well - this will be needed for Thunc.
- Added an image interface to renderer (load and draw - will add save maybe. Not sure I want image editing). 

<img src="media/2025-10-23_13-58.png">

More features/plugins incoming - a lua debugger, a project workspace (think like vscode ish), extension/plugin handling (able to enable/disable in workspace), some embedding features needed for Thunc.

Id also like to make a git integration but higher level. Where the versioning and control of it is more decoupled and easier for people to use - ie no knowledge of git would be needed. And it would handle art assets, code and binaries very differently (think AlienBrain if you have ever used that :) )

Again. Cant thank rxi enough. This is an utterly powerful tool. I will be sending you some sponsorship rxi!

## Lite

This project would not exist without lite:

https://github.com/rxi/lite/tree/master

Lite is a brilliant simple lightweight text editor written in lua. And supports plugins and more.

Checkout the plugins here. Most work with dim (with minor adjustments).

https://github.com/rxi/lite-plugins

Being written in Lua it means that it can work with sokol-luajit that I have put together. The benefits here means there is nothing to build (unless you want to pack it into a simple bundle :) ) and the platforms can be varied - It should initially work on Win, OSX and Linux without too many problems.

I also expect it should be able to be built for Android and IOS as well with some extra work (Testing and lib building might be needed)

If you want the builds for the sokol-luajit system. They can be found here:

https://github.com/dlannan/sokol-build/

Note: There are slight variances in these versions vs the original sokol (like being able to disable clear on a new_frame) but they should be highly compatible. As sokol is improved or bug fixes added I will try to keep this relatively closely sync'd.

The intended use for this will be in the sokol-luajit editor (Thunc). It will allow the easy editing, loading, saving of game engine scripts. Debugging should also be able to be added (future goal).

