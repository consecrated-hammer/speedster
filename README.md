## Speedster

Speedster is a lightweight World of Warcraft Classic Anniversary addon that generates a class-aware movement speed macro and binds it to a key through a simple options panel.

Originally inspired by MountsJournal, which unfortunately isn't available for TBC Anniversary.

## What It Does

- Builds a dynamic movement macro based on your class and known spells.
- Updates automatically when you learn new relevant spells/forms.
- Lets you bind your preferred key or mouse button from the options panel ("press next key/button" capture).
- Exposes separately bindable learned movement, descent, terrain-travel and escape actions.
- Shows your currently generated macro in the options panel.
- Optional flight master support can auto-cancel form/dismount so you can select a taxi destination without manual unshifting.

## Supported Class Speed Abilities

- Druid: Cat Form, Aquatic Form, Travel/Flight Form logic (when known)
- Shaman: Ghost Wolf
- Hunter: Aspect of the Cheetah
- Rogue: Sprint
- Mage: Blink

## Additional Bindable Actions

When the character knows one of these abilities, it appears in **Additional
movement actions** in Speedster's options with its own **Bind Key** control.
No action is bound automatically.

- Druid: Dash
- Hunter: Aspect of the Pack (shown with its daze warning)
- Mage: Slow Fall
- Priest: Levitate
- Shaman: Water Walking
- Paladin: Blessing of Freedom (self-cast)
- Gnome: Escape Artist
- Skyborne: Walk on Air and, for Windshapers, Skysight

Slow Fall and Levitate consume Light Feathers; Water Walking consumes Fish Oil.
The normal Speedster key remains independent, so a player can use any desired
key or mouse button for each available action.

If your class has no supported speed spell available yet, the generated macro will be empty until one is learned.

## Usage

1. Open options:
   - `/speedster`
2. Bind a key:
	   - Click **Bind Key**, then press the key/button you want.
	   - Use the separate **Bind Key** control beside any learned additional action.
   - Or use `/speedsterbind [KEY]` (empty value defaults to `NUMPADMINUS`).
3. Inspect generated macro text:
   - `/speedstermacro`

## Commands

- `/speedster` - Open Speedster options
- `/speedsterbind [KEY]` - Bind speed macro to a key
- `/speedstermacro` - Print current generated macro
