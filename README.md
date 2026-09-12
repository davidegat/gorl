# GORL - Gat's Own ROM Launcher

GORL is an MSX ROM launcher for the OneChipBook. It scans the SD card, shows the available games in a menu, and launches compatible ROM images directly from the SD card.

## Tested hardware

Tested on the **OneChipBook-12**:

- Altera Cyclone **EP1C12Q240C8N** FPGA
- 12,060 logic elements
- 239,616 embedded memory bits
- 32 MB SDRAM
- 1024x768 built-in display
- built-in SD card interface

## ROM support

GORL supports:

- plain **8 KiB**, **16 KiB** and **32 KiB** ROMs
- compatible software-mapped ROMs up to **1 MiB**

**64 KiB ROMs do not work and are intentionally rejected by the launcher.**

Place ROM files in:

```text
/ROMS
```

Supported filename extensions are:

```text
.ROM  .SCC  .A8  .A16  .D2R
```


## `gametitles.txt`

GORL can use a file named **`gametitles.txt`** in the same `/ROMS` directory as the ROM files. It associates the short DOS filename used on the SD card with the full title shown in the launcher menu.

Each line has this format:

```text
DOSNAME.EXT Full game title
```

Example:

```text
1942_-_C.ROM 1942
A1_SPIRI.ROM A1 Spirit
ROAD_FIG.ROM Road Fighter
```

The first field must exactly match the ROM filename. Everything after the first space is the title displayed by GORL.

The ROM preparation tool described below creates and maintains this file automatically. It is supplied in Python, Bash and Windows BAT versions. On every run it:

1. keep titles that already belong to ROMs still present;
2. ask only for titles that are missing;
3. remove obsolete entries whose ROM is no longer present;
4. rewrite `gametitles.txt` so it matches the current contents of the directory.

If a ROM is deleted from `/ROMS`, its line is automatically removed from `gametitles.txt` the next time the tool is run. If no ROMs remain, `gametitles.txt` is emptied.

For maximum MSX compatibility, use plain ASCII characters in game titles.

## ROM preparation scripts

Three equivalent versions of the same tool are supplied:

```text
gorl-romprep.py   Python 3
gorl-romprep.sh   Bash
gorl-romprep.bat  Windows
```

You only need to use **one** of them. Each script performs the complete preparation process; the old separate rename/title scripts are no longer required.

The script works on the **current directory** and performs these operations in order:

1. finds `.ROM`, `.SCC`, `.A8`, `.A16` and `.D2R` files;
2. renames them in place to safe **DOS 8.3** filenames;
3. resolves duplicate DOS names automatically with suffixes such as `_1`, `_2`, etc.;
4. asks for the full game title when no title is already known;
5. creates or updates `gametitles.txt`.

For example, a file such as:

```text
A1 Spirit (Konami).rom
```

may become:

```text
A1_SPIRI.ROM
```

The full title can still be displayed as `A1 Spirit` through `gametitles.txt`.

**The ROM files are renamed directly.** Make a backup first if you want to preserve the original filenames.

### Python version

Requires Python 3. Open a terminal in the directory containing the ROMs and run:

```bash
python3 gorl-romprep.py
```

On Windows, if Python is installed through the standard launcher, this also works:

```bat
py gorl-romprep.py
```

### Bash version

On Linux, including Pop!_OS:

```bash
bash gorl-romprep.sh
```

or make it executable once:

```bash
chmod +x gorl-romprep.sh
./gorl-romprep.sh
```

### Windows BAT version

Copy `gorl-romprep.bat` into the directory containing the ROMs and either double-click it or run:

```bat
gorl-romprep.bat
```

The BAT version uses **Windows PowerShell**, which is included with normal Windows 10/11 installations. Python is not required for the BAT version.

### Recommended workflow

Prepare the SD card on the PC, open the `/ROMS` directory, copy one of the scripts there, then run it. Enter the full title for each new game when requested. Pressing **Enter without typing a title** uses the DOS filename stem as the title.

After the script finishes, the directory will contain the renamed ROM files plus:

```text
gametitles.txt
```

Keep `gametitles.txt` in `/ROMS` together with the ROMs when using the SD card in the OneChipBook.

If you later add or delete games, simply run the same version again. Existing titles are kept, **only newly added ROMs are asked for**, and title entries for deleted ROMs are removed automatically.

## SD card

Format the SD card with:

- an **MBR** partition table
- one **primary FAT16** partition

To launch **MSX-DOS** from GORL with `CTRL+D`, MSX-DOS must be installed and bootable on the same SD card.

## OneChipBook DIP switches

- **DIP 2** - video mode configuration
- **DIP 4** - enables/disables rear cartridge Slot 1
- **DIP 5 + DIP 6** - select the Slot 2 configuration: internal mini-slot, ASCII8, SCC or ASCII16
- **DIP 8** - enables the SD card mass-storage interface; it must be enabled to use GORL from SD

## Programming the OneChipBook

Use **Quartus II 13.0 SP1 Programmer** and a **USB-Blaster** connected to the OneChipBook Active Serial Programming port.

Programmer settings:

- **Hardware:** USB-Blaster
- **Mode:** Active Serial Programming
- **Configuration device:** EPCS4
- **File:** the supplied `.pof`
- enable **Program/Configure**
- click **Start**

## Tested titles

- 1942
- A1 Spirit
- Adventure Kid
- Aladdin
- Alex Kid
- Alibaba And 40 Thieves
- Antarctic Adventure
- Arkanoid 2
- Arkanoid
- Athletic Land
- Beamrider
- Blagger
- Block Hole
- Bomb Jack
- Booty
- Bosconian
- Boulder Dash
- Bruce Lee
- Burger Time
- Butamaru
- Cabbage Patch Kids
- Car Jamboree
- Chack'n Pop
- Champion Pro Wrestling
- Championship Lode Runner
- Choplifter
- ChoroQ
- Chuckie Egg
- Circus Charlie
- City Connection
- Comic Bakery
- Congo Bongo
- Crusader
- Decathlon
- Deep Forest
- Dig Dug
- Doki Doki Penguin Land
- Donkey Kong
- Donkey Kong Jr.
- Door Door mkII
- Dorodon
- Double Dragon
- Dragon Quest 1
- Dragon Slayer 1
- Eggerland
- Elevator Action
- Elite
- Exerion 1
- F15 Strike Eagle
- F1 Spirit
- Fantasy Zone 1
- Final Mahjong
- Frogger
- Galaga
- Galaxian
- Ghostbusters
- Gradius
- Green Beret
- Grog's Revenge
- Guardic
- Gulkave
- Gyrodine
- H.E.R.O.
- High School Kimengumi
- Hydlide
- Hydlide 1
- Hyper Olympic 1
- Hyper Rally
- Hyper Sports 1
- Hyper Sports 2
- Hyper Sports 3
- Jack The Nipper
- Jet Bomber
- Jet Set Willy
- Joe Blade
- Jungle Hunt
- Jungle Hunt
- Juno First
- King's Valley 1
- Knight Lore
- Knightmare
- Konami's Baseball
- Konami's Boxing
- Konami's Golf
- Konami's Ping-Pong
- Konami's Soccer
- Konami's Tennis
- Kung-Fu Master
- Lode Runner
- Magical Tree
- Manic Miner
- Mappy
- Monkey Academy
- Moon Patrol
- Mopiranger
- Nemesis 1
- Nemesis 2
- New Bubble Bobble
- Night Shade
- Ninja Jajamaru Kun
- Ninja Kun
- Ninja Princess
- Oh Shit
- Oil's Well
- Operation Wolf
- Othello
- Pac-Man
- Parodius
- Penguin Adventure
- Pippols
- Pitfall!
- Pitfall II
- Polar Star
- Pole Position
- Pooyan
- Pyramid Warp
- Q-Bert
- R-Type
- Racing v1.0
- Raid On Bungeling Bay
- Rambo
- Rescue Operation
- Return Of Jelda
- River Raid
- Road Fighter
- Roller Ball
- Salamander
- Scramble Eggs
- Sky Jaguar
- Solar Fox
- Sorcery
- Space Camp
- Space Invaders
- Spelunker
- Star Force
- Streetfighter
- Super Boy II
- Super Boy I
- Super Bubble Bobble
- Super Cobra
- Survivors
- Tales of Popolon
- Tank Battalion
- Tetris
- The Black Onyx 1
- The Castle
- The Goonies
- The Heist
- The Way Of The Tiger
- Thexder
- Time Pilot
- Tutankham
- Twinbee
- Twinbee
- Valkyr
- Vaxol
- Victorious Nine 2
- Volguard
- Warroid
- Who Dares Wins
- Xevious Micro
- Xyzolog
- Yie Ar Kung-Fu II
- Yie Ar Kung-Fu
- Zanac A.I.
- Zaxxon
- Zexas
- Zippy Race
