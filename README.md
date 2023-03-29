# bm-hotspot-cli

## Manage Talkgroups on your Hotspot via Brandmeister-API

![Screenshot](Screenshot.png)

[Original code by cascha42](https://github.com/cascha42/bm-hotspot-cli)

### Modifications to original code
- Moved important variable settings out of the main program
and into a config file.
- Updated code base to work with the new Brandmeister API version (v2)
- Fixed the jq parsing errors
- Minor usability and UI changes
- Added caching of TS, TG and hotspot information.  Any changes made to the
timeslots and talkgroups will trigger a refresh of the information, otherwise
the program uses the cache file.
- Added an option to show basic hotspot information.
