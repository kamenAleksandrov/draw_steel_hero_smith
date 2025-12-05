
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

some hero classes and features grant skills. those skills may have been picked in another choice nod earlier. if there is such an occurence the logic should accomudate. 

the stamina gauge shouw be divided into 3 sections based on the dying, winded and helthy values.

the projects item card has a required items [] when non are present and instead it should be none. sam is for knowledge

in the hero creator stranght tab the automaticaly applied appears doubled each time

automatically applied must be as a divider instead as another box that boxes the box

project add points button can be made into a roll button.
## medium

growing ferocity tabels are not implemented

need to add a loading screen noting that this is not an official product and is working on their rules.

most popouts should be wider

abilities cards inside should strech the whole width, example: kits

item ench must grant abilities

titles must grant their abilities

must add treasure abilities

some features need their abilities: covenant of the hearth

sometimes heros cant load certain features

the features tab in features sheet deos not tailor to the choices of the user for the her, instead it shows ALL features.

there is some scroll error in the strenght. when i try to go back up a bit faster and let the screen flow on its own by pulling faster and letting it go it starts twitching in one place and a reloadis seen

need to add a perks field to the features sheet

there should be a way to show what condition immunities does a hero have
## hard

on my phone some elements do not update on time

the storing of equasion and calculation must be applied accross the board. not just the woadwalker recovery bonus

there are false save and duplication flags on the strife page

there is a visible reload in the growing ferocity widget and i need it gone

the growing ferocity tabel should show only the reached and unlocked values, the rest should be idden behind a dropdown,

the gear page should look through every item in the heros inventory  and check the grants and their conditions to summ them all and add to the hero stats

when picking a class and chosing the same class as the current the choises should not reset.

## need testing

ancestry traits should have their longer text displayed and if its too cluttered have to display fixed - may not have it in the db - it is missing take it from forge steel

abilities should show all abilities that the hero gains including ones gained by class or a feature ex: judgment, my life for yours and etc. - i think is fixed

treasures that are already in the gear of a hero should not be removed when i try to add them by the downtime project - i think its fixed

Reload flicker came from the async providers returning to their loading states on every hero update. I removed the nested `AsyncValue.when` blocks and now we reuse the latest progression/context values via `valueOrNull`, so the gauge keeps showing stale data while Riverpod refreshes in the background. If both values are still null (first load) the section stays hidden just like before. This should eliminate the twitching when only the resource value changes.

## hero creation testing

reorder the tabs: strife => strength => story?

it might be a good idea to have the features that upgrade other features do so in the ui but idk yet

strenght tab lack the option to save choises which leads to lost picks

duplicate marks saveing the page for duplication wrongfully

perks from the strife page do not save their abilities to the hero.

auto granted features must have theri names shown too

in the strife page expanded cards close when they move out of sight and this move the app scroll and is annoying.

the resource addition buttons should update each time the heroes base go up

perks in the hero creator strife do not show all their pick and choices as they do in the story.

level 10 features have more work to be fully functional.

hero card does not update if i dont restrart the app

rn update the resource generation, the oprions and grants and the subclass abilities

the choose a characteristic level bonus is removed upon chosing a new value for the widgets and their picker below. this should be fixed.

in the creator there are cost categories and they load for each ability, insetead group abilities under one

characteristics scores bonuses at higher levels do not save to the character

changing class should prompt for confirmation

this calss does not grant additional perk pics should be removed for level 1

the hero class skill and ther features bonuses do not save or grant their bonuses

some features that have multiple new lines must be better organised or atleast spaced one empty row apart.

i have to look through all the first level subclass choices and decide how and where what is displayed. example - the tactician has a subclass choice in the strife page, then in two places has the tactical doctrine feature, once as the grant and the second time is as a choice/exlplanation of the doctrine

some abilities may deserve a main stats ui examples are: judgement, mantle of essence, mark, routines, troubadour drama gain, growing ferocity and discipline

subclass abilities now show but must be tailored to the subclass
### censor

features do not grant the bonus skill form the domain.

the 2nd level fetures are both granted, not a choice.

### conduit

the conduit has extra generation methods and prayer effects that must take their information from the features file where we have the piety generation and the prayer effect. the prayer must be seen in the 1d3 generation and the piety in the piety feature

the strenght triggered actions mark the 2 options

the "id": "feature_conduit_domain_piety_and_effects", now devides the grants in domain, piety and prayer effect.

the domain feature must grant the option fo chosing a skill from the group

level 2,5,8 domain feature should be the same as the previous level one but instantly grant the one that the user DIDNT pick the previous level.

the level 2,6 5 csot abilities widget should load the 2 abilities that match the name of the domains and let the user pick one.

### elementalist

1rts level feature doan not find the void spec. could be fixed on reinstall but would be nice to have it receed the jsons on updates. this will make it easier to update without losing info

elementalist 2nd, 6th, 9th levels does not have subclass dependent abilities but it lets the user pick from the new and old x cost abilities that the user dindt take.

would be cool to have the mantle of essence like the fury or null growing resource.

### fury

1rst level strength page primordial aspect shows as choice required but the choice is already made in the strife page 

the primordial storm type and its damage type in the kits should be displayed better

### null

the null must get bonus to speed and disengage equal to agility
 
the null has acces to only the Density Augmentation, Force Augmentation and Speed Augmentations

the psi boosts are not loaded into the class, i think creating a ui for them would be appropriate.

null 9th level am the weapon gives +21 stamina which should be reflected in the hero sheet

### shadow

shadow firt level colledge feature was missing so i added it. whats important is to make sure that the cod can handle 2 entries in the json for the subclass and grant them both

### tactician

### talent

the talent is the only class that can go into negative heroic resource and must be handled in the code and json.

### troubadour

routines dont grant the two starting reoutines

level 4 melodrama has the option to choose 2 options and i don think i handle this at the moment

level 4 zeitergeit is a feature example that the sheet page should let the user repick choices and keep them saved

level 5 feature lets the user pick 2 features of their subclass but the widget in strength lets them pick 1 of all an just shows the subclass

;level 8 feature does not load the virtuoso crowd favourites

