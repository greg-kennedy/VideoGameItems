# VideoGameItems
Source code and data repository for the [@VGItems](https://twitter.com/VGItems)  Twitter account

## Overview
This repository contains the source code and data files for the Twitter bot [@VGItems](https://twitter.com/VGItems).  The bot posts a random item, extracted from a video game, every few hours.

## Usage
`main.pl` is the primary script.  It reads in `config.pl` for API info to connect to Twitter, and selects a screenshot at random from the `data/` subfolder.  It will make a single post to the site using the image, and provide a description of the object according to a pre-defined template using data from an `index.json` file located at the root of each game's subfolder.

Of course, you shouldn't run it manually.  Edit your `crontab` file and add a line like the following:

    0 4,10,16,22 * * * cd /home/userid/VideoGameItems && ./main.pl >/dev/null 2>&1

This line will launch the bot at 4 AM, 10 AM, 4 PM and 10 PM each day.

## Data
All item images and associated text are stored in the `data/` subfolder, grouped roughly by system and then game title.  During launch, the script will recursively search every subfolder for files called `index.json`, which should contain some information about each game and then a list of items with individual descriptions.  All objects should be in `.png` format, preferrably optimized for minimum filesize, and they should be extracted directly from the game data - no screenshots, mockups or recreations allowed.  Descriptions should also be sourced from in-game text where available.

A random entry from the entire collection of index documents is chosen and posted with its description.

## Contributing
This project accepts contributions!  You may submit a PR to add another game to the pool.  Please follow these guidelines when contributing:

* The objects should be items that the player can possess and "use" in the game, in some form of inventory or item slot.  This excludes things like collectables and powerups that activate immediately.  So while the Super Mushroom from Super Mario Bros. is not allowed, the Super Mushrom from Mario 3 is fair game.
* No item "classes", like the 'armor' icon from Final Fantasy which represents more than one armor.
* No randomly-generated items.  For example, the Unique items from Diablo II are acceptable, but the Magical items are not.  Minor variation within an item is acceptable in some cases.
* Item images and descriptions should be taken directly from the game data files.  Don't make up a description if there isn't one - just leave it blank!  Try to source names from the game, or if items are unnamed, check the manual, strategy guide, etc.
* Prefer English text, please.
* Try to get *all* the items in one commit.
* Compress images first, using [OptiPNG](http://optipng.sourceforge.net/), [PNGOUT](http://advsys.net/ken/utils.htm), etc.  Make sure to use a lossless tool (no pngquant!)

Squash PRs into a single commit, and submit only one game per PR: this makes it easy to browse in history, as well as avoiding large changesets in multiple places in the Git history.

## Contact
Easiest way to reach me with questions is to send a message on Twitter at [@greg\_p\_kennedy](https://twitter.com/greg_p_kennedy), or email to [kennedy.greg@gmail.com](mailto:kennedy.greg@gmail.com).

## License
All source code in this repository is released into the public domain.

UNLESS EXPLICITLY NOTED OTHERWISE (see respective `index.json`), ALL IMAGES AND TEXT ARE UNDER COPYRIGHT of the associated game developer, publisher, or other owner.  We allege "fair use" under artistic purposes strictly limited to hosting this data, and re-posting it at random under the @VGItems Twitter account.  Please contact via the [Issues tab](https://github.com/greg-kennedy/VideoGameItems/issues) to opt-out / request removal.
