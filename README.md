## Speedster

Speedster is a lightweight World of Warcraft Classic Anniversary addon that generates a class-aware movement speed macro and binds it to a key through a simple options panel.

Inspired by the design ideas behind MountsJournal.

## What It Does

- Builds a dynamic movement macro based on your class and known spells.
- Updates automatically when you learn new relevant spells/forms.
- Lets you bind your preferred key from the options panel ("press next key/button" capture).
- Shows your currently generated macro in the options panel.

## Supported Class Speed Abilities

- Druid: Cat Form, Aquatic Form, Travel/Flight Form logic (when known)
- Shaman: Ghost Wolf
- Hunter: Aspect of the Cheetah
- Rogue: Sprint
- Mage: Blink

If your class has no supported speed spell available yet, the generated macro will be empty until one is learned.

## Usage

1. Open options:
   - `/speedster`
2. Bind a key:
   - Click **Bind Key**, then press the key/button you want.
   - Or use `/speedsterbind [KEY]` (empty value defaults to `NUMPADMINUS`).
3. Inspect generated macro text:
   - `/speedstermacro`

## Commands

- `/speedster` - Open Speedster options
- `/speedsterbind [KEY]` - Bind speed macro to a key
- `/speedstermacro` - Print current generated macro

## Notes

- Macro updates automatically on spell changes.