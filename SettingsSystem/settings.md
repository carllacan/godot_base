# Settings system
## Description
* The settings system includes several classes that streamline the creation of new settings for a game, as well as the creation of settings UI.

## Classes
### SettingInfo
* Allows the developer to configure a setting: id, value type, allowed values...
### SettingsContainer
* Custom resource that contains the current settings, keyed by the id of each setting, so a file written by one build still reads in the next one. Can be easily saved to a file.
* The defaults resource also carries `known_settings`, the catalog that turns an id back into its SettingInfo. Containers written to disk hold values alone.
### SetingsManager
* Intended to be used as a singleton named Settings, provides acces to the current settings, as well as automated loading/saving.
