# Settings system
## Description
* The settings system includes several classes that streamline the creation of new settings for a game, as well as the creation of settings UI.

## Classes
### SettingInfo
* Allows the developer to configure a setting: name, value type, allowed values...
### SettingsContainer
* Custom resource that contains the current settings. Can be easily saved to a file.
### SetingsManager
* Intended to be used as a singleton named Settings, provides acces to the current settings, as well as automated loading/saving.
