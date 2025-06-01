Just a .mod player for the Sega/Mega-CD. Building requires a native C compiler (preferably `gcc`) and [vasm](http://sun.hasenbraten.de/vasm/).

## Notes

* Due to the limits of the sound chip, the module can't contain more than (a bit less than) 64k of samples.
* Very short looped "chip" samples sound a bit off tune in some emulators. Don't know if this is an issue on a real Sega CD.
* No proper Ultimate SoundTracker detection, so very old modules have issues (wrong speed or arpeggios).
* Up-to-8-channel modules are theoretically supported but not tested (probably not likely any modules like this with <64k of samples exist).
* `E0x`, `E3x`, and `EFx` effects will never be supported.
* The supplied build is for US systems. Replace the `incbin security-u.bin` in `src/main.asm` to build for a different region.