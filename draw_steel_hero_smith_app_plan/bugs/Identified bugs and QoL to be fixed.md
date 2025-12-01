
## easy

project points from background should be availavable?

the notifications of saving and or the random displays that pop out of the bottom must be removed upon release

need to add an icon.

when clicking any field that accepts values in the creator the ap should not defopult to typing in the field

cannot save the word of guidance in the features panel

features that require a choise need to be noted

recoveries must better show their value

the A in ability cards sometimes is not colored properly

chaging fury subclass must remove stormwight kits

the hero card in the starting screen does not uptade changes to class (maybe more)

save 6+ must be save 6 or save >= 6
## medium

growing ferocity tabels are not implemented

need to add a loading screen noting that this is not an official product and is working on their rules.

most popouts should be wider

abilities cards inside should strech the whole width, example: kits

item ench must grant abilities

titles must grant their abilities

must add treasure abilities

sometimes heros cant load certain features

## hard

on my phone some elements do not update on time

the storing of equasion and calculation must be applied accross the board. not just the woadwalker recovery bonus

there are false save and duplication flags on the strife page

there is a visible reload in the growing ferocity widget and i need it gone

the growing ferocity tabel should show only the reached and unlocked values, the rest should be idden behind a dropdown,

## need testing

ancestry traits should have their longer text displayed and if its too cluttered have to display fixed - may not have it in the db - it is missing take it from forge steel

abilities should show all abilities that the hero gains including ones gained by class or a feature ex: judgment, my life for yours and etc. - i think is fixed

treasures that are already in the gear of a hero should not be removed when i try to add them by the downtime project - i think its fixed

Reload flicker came from the async providers returning to their loading states on every hero update. I removed the nested `AsyncValue.when` blocks and now we reuse the latest progression/context values via `valueOrNull`, so the gauge keeps showing stale data while Riverpod refreshes in the background. If both values are still null (first load) the section stays hidden just like before. This should eliminate the twitching when only the resource value changes.

## hero creation testing



