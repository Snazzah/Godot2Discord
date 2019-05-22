# Godot2Discord
Connect to Discord in Godot with no GDNative hassle

**NOTE:** Only works in Windows at the moment

## Usage

Insert the `discord` folder into anywhere in the project, then either make it a singleton or initialize

```py
Discord.id = "579833296964550656"
if Discord.can_use:
  Discord.start()
  Discord.set_activity({
      'assets': {
      'large_image': 'icon'
    },
    'details': "In Menus"
  })
```
