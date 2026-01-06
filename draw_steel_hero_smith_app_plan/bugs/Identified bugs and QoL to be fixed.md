
## easy

features that require a choise need to be noted

chaging fury subclass must remove stormwight kits

in the hero creator stranght tab the automaticaly applied appears doubled each time

automatically applied must be as a divider instead as another box that boxes the box

skills dialog picker in strenght uses old style 
## medium

most popouts should be wider

abilities cards inside should strech the whole width, example: kits

item ench must grant abilities

titles must grant their abilities

must add treasure abilities

modification popuots should not have an already set value of 0
## hard

the storing of equasion and calculation must be applied accross the board. not just the woadwalker recovery bonus

there are false save and duplication flags on the strife page

the gear page should look through every item in the heros inventory and check the grants and their conditions to summ them all and add to the hero stats

when picking a class and chosing the same class as the current the choises should not reset.

create a equipment functionality where the user can equip items and get their bonuses

update abilities to be dynamic based on the hero stats

add export hero as a file

perks form career give false duplication errors on skills
## need testing

ancestry traits should have their longer text displayed and if its too cluttered have to display fixed - may not have it in the db - it is missing take it from forge steel

abilities should show all abilities that the hero gains including ones gained by class or a feature ex: judgment, my life for yours and etc. - i think is fixed

treasures that are already in the gear of a hero should not be removed when i try to add them by the downtime project - i think its fixed

Reload flicker came from the async providers returning to their loading states on every hero update. I removed the nested `AsyncValue.when` blocks and now we reuse the latest progression/context values via `valueOrNull`, so the gauge keeps showing stale data while Riverpod refreshes in the background. If both values are still null (first load) the section stays hidden just like before. This should eliminate the twitching when only the resource value changes.

Switched the Strife Creator page from a sliver-based scroll (`ListView`) to a non-recycling scroll (`SingleChildScrollView` + `Column`) so Abilities/Skills/Perks don’t get collapsed/removed/relaid out when you scroll past them.

strenght tab lack the option to save choises which leads to lost picks

some features need their abilities: covenant of the heart

the A in ability cards sometimes is not colored properly

the notifications of saving and or the random displays that pop out of the bottom must be removed upon release

the projects item card has a required items [] when non are present and instead it should be none. sam is for knowledge

some hero classes and features grant skills. those skills may have been picked in another choice nod earlier. if there is such an occurence the logic should accomudate. 

on my phone some elements do not update on time

the hero class skill and ther features bonuses do not save or grant their bonuses
### unnecessary changes

add a gold/silver/copper to the wealth stat and make it have both.

reorder the tabs: strife => strength => story?

it might be a good idea to have the features that upgrade other features do so in the ui but idk yet

in the creator there are cost categories and they load for each ability, insetead group abilities under one?

some features that have multiple new lines must be better organised or atleast spaced one empty row apart.

i have to look through all the first level subclass choices and decide how and where what is displayed. example - the tactician has a subclass choice in the strife page, then in two places has the tactical doctrine feature, once as the grant and the second time is as a choice/exlplanation of the doctrine 

some abilities may deserve a main stats ui examples are: judgement, mantle of essence, mark, routines, troubadour drama gain, growing ferocity and discipline

changing class should prompt for confirmation

level 10 features have more work to be fully functional.

would be nice to have it receed the jsons on updates. this will make it easier to update without losing info

remove duplication finding?

### necessary changes


features must have ui updated to handle options, grants and other such cases better.
## hero creation testing

### censor

### conduit

### elementalist

would be cool to have the mantle of essence like the fury or null growing resource.

### fury

### null

### shadow

### tactician
### talent

### troubadour

