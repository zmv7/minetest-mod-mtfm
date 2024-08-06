# minetest-mod-mtfm
Formspec-based file manager with text editor and image viewer  
[![ContentDB](https://content.minetest.net/packages/Zemtzov7/mtfm/shields/downloads/)](https://content.minetest.net/packages/Zemtzov7/mtfm/)
### Usage
* Chatcommand `/mtfm [path]` - open file manager, optionally path(absolute) can be specified
* Click `Modlist` button to get list of installed mods, then you can browse their files
* `.png` files are opened in image viewer
* `.ogg` files are played by opening
* Empty files can not be auto-opened in text editor, use `Edit` button to force it  
* Read-only mode can be enabled in settings or in minetest.conf: `mtfm.read_only = true`
* Set `secure.enable_security = false` in the `minetest.conf` to get full RW access to your homedir

### DISCLAIMER
* Wrong usage of this mod can destroy you local world / server
* Developer of this mod is not responsible for your actions


![](/screenshot.png)
