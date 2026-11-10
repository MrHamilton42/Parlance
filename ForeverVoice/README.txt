PARLANCE 0.5.0

Install
Extract the ForeverVoice folder into your client's Interface/AddOns folder.
Use World of Warcraft/_forever_/Interface/AddOns for Forever or
World of Warcraft/_retail_/Interface/AddOns for Retail. Restart the client
after installing or updating. Enable Parlance in AddOns and type /parlance
on your character. Each client keeps its own character settings.
When upgrading from Forever Voice, replace the files in its existing
ForeverVoice folder to retain your settings. The /fvo command still works.

Add an ability
1. Click New ability. Enter a spell ID or click Capture next cast and use the
   ability while the editor is open. Try an out-of-combat cast first.
2. Type one line per row. Emotes start after your character's name, for example
   "raises a fist in triumph." Speech contains the words your character says.
3. Set Emote % and Speech %. At 15% emote and 10% speech, Nothing is 75%.
   Each eligible cast has one outcome. If it chooses a list, every row in that
   list has an equal chance. A list with a nonzero chance needs at least one line.
4. Click Save rule. Use the dropdown to switch between saved rules.

The default cooldown is eight seconds between lines across all abilities. Casts
during that window are skipped. Silent rolls leave the cooldown alone. Settings
and rules are stored per character. Different spell ranks can have different IDs.

Text and voice
By default lines appear in your local chat window. Try public chat opts in to
nearby /say and /emote where WoW allows addon chat. If the client reports
lockdown or the call errors, the line appears locally. Server chat filters can
still affect delivery. Custom emotes are text actions.

Check Read aloud locally and use a Preview button to try the first line in
either list. Use My preferred voice to choose one of the voices available in
WoW on this computer. Hear sample plays a local sample. Choose WoW default to
use your Accessibility voice. Speed and volume also use Accessibility settings.

Choose Narrator voice for emotes to read action lines in a separate voice.
For example, "waves hello." is read as "[Character name] waves hello."
Hear narrator plays a sample. The setting also applies to emotes shared by
players using version 0.4.0 or later. It controls the narration you hear on
this character. Choose Use character voices to return to the usual playback.
If a selected narrator voice becomes unavailable, narration uses WoW's default.

Enter a phonetic spelling in Name pronunciation if the narrator misreads
your name. For example, try "KAY-len" and click Save, then Hear narrator.
Clear the field and save to use your character's actual name in narration.
With Share with group enabled, the spelling travels with your emotes.
Listeners using version 0.4.1 or later hear it when they use a narrator voice.
Chat displays your actual name.

Group voice and distance
Enable Share with group on the character speaking. Other party or raid members
with Parlance can enable Hear nearby group lines on their characters.
These are separate switches. Each listener's volume fades with distance,
measured when the line arrives.

When you share a line, the addon sends the name of your preferred voice if
you chose one. The listener looks for that name in their own WoW voice list.
They can use Voices I hear for friends to choose a voice for any character in
their WoW character friends list. Choose Use speaker preference to clear an
override. These overrides are saved on the listening character and stay local.
Playback tries the override first, then the speaker's choice, then the
listener's WoW Accessibility voice or the first voice WoW lists.

Put an optional tag at the start of a speech or emote line. For example,
`[whisper] Stay close.` plays just "Stay close." Tags ignore letter case.
The tag is omitted from spoken audio and chat text.

Delivery        Volume up close        Fades to silence at
[whisper]       35% of base            8 yards
[quietly]       60% of base            18 yards
No tag          100% of base           30 yards
[yell]          100% of base           60 yards

The distance rule applies to shared audio. Local previews play at the
up-close volume. Shared playback requires a readable distance to the sender.
WoW can withhold that distance or block addon messages, especially in instances.
The listener drops additional incoming lines for two seconds after playback
starts. Sharing uses the regular party or raid, with both sharing and listening
off until enabled.

Macro trigger for hidden cast IDs
If WoW hides the spell ID during combat, enable Trigger by macro for that rule
and save it. Add the /parlance fire line shown in the editor beneath your normal cast:

  #showtooltip
  /cast Spell Name
  /parlance fire 12345

Replace Spell Name and 12345. This triggers on the macro press, so a line can
play even if the cast fails. The corresponding rule uses the macro press as its
only trigger. The game's chat restrictions still apply.

Verification
Targeted at Forever 1.60.1 and Retail 12.1.5. The Lua tests simulate cast events,
communication restrictions, sender matching, volume falloff and voice selection.
In game, use /parlance and click Hear sample to check local voice playback. Live group
delivery needs a two-player check on the same client.
