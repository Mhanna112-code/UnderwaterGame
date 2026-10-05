# Current-main native feedback packages

Release: https://github.com/Mhanna112-code/UnderwaterGame/releases/tag/main-feedback-7336611
Runtime source: `7336611fcaeed8e03c875fdb3e0118facd7737df`, same as the current
canonical Web runtime. No runtime diff against that commit before either export;
only verification/docs edits. Godot4.7.1 cross-exported on macOS. Windows/Linux
release templates produce PE32+ x86-64 / ELF64 x86-64 respectively. Both exports
exit0 without engine/script/export errors. Both ZIP integrity checks pass.

The draft release assets were independently downloaded with authenticated gh;
downloaded archives satisfy the shipped SHA256SUMS. Published as a prerelease,
not latest, preserving earlier packages. GitHub asset digests also agree with
local and downloaded hashes. No Windows/Linux target launch/playtest is claimed.
These packages do not establish full campaign, balance or browser acceptance.

`native-packages-7336611.json` records archive/payload/executable identities.
Windows and Linux common native payload SHA256 is7a4e883f; the Web payload is
ae9f15f6 because export platforms differ. Play.bat/Play.sh select Compatibility
rendering; full extraction, unsigned security caution and separate native-save
instructions ship in each ZIP. Existing native saves are not erased or migrated.

Opening review remains deferred and gated. Refresh these packages after any
future runtime changes; a metadata-only publication keeps game bytes identical.
