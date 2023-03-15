![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

# HOVALAAG CPU for Tiny Tapeout

[HOVALAAG](http://silverspaceship.com/hovalaag/) (Hand-Optimizing VLIW Assembly Language as a Game) is a free Zachlike game.

[HovalaagCPU](https://github.com/MichaelBell/HovalaagCPU) is my Verilog implementation of the CPU from the game. This is a project to implement it on Tiny Tapeout.

Thank you to @[nothings](https://twitter.com/nothings) for the fun game, making the assembler public domain, and for permission to create this hardware implementation.

# Implementation details

The processor is described in detail on the game pages.  Here we will document the wrapper to allow it to be used through Tiny Tapeout.

The processor uses 32-bit instructions and has 12-bit I/O.  Tiny Tapeout effectively has 6 bits input and 8 bits output per clock (because 2 input bits are required for clock and reset).

The instruction and data therefore need to be passed in and out over several (currently 10) clocks per processor clock.  The cycle is as follows:

| Clock | Input 7-2 | Output |
| ----- | ----- | ------ |
| 0     | Instruction 5-0 | Register A for debug |
| 1     | Instruction 11-6 | Register B for debug |
| 2     | Instruction 17-12 | Register C for debug |
| 3     | Instruction 23-18 | Register D for debug |
| 4     | Instruction 29-24 | Register W for debug |
| 5     | Instruction 31-30 | IO update indication |
| 6     | New IN1 5-0       | New PC |
| 7     | New IN1 11-6      | OUT 7-0 |
| 8     | New IN2 5-0       | OUT 11-8 |
| 9     | New IN2 11-6      | OUT 3-0 for 7 segment display |

The IO update indication bits on the 6th clock are as follows:
| Bit | Meaning |
| --- | ------- |
| 0   | Advance IN1 |
| 1   | Advance IN2 |
| 2   | Write OUT to OUT1 |
| 3   | Write OUT to OUT2 |

The implemented design also adds the following ALU ops in the unused range (originally documented as BCD conversions, but previously never used):
```
1101   A
1110   Random 6-bit number
1111   The constant 1
```

## TODO

Physical testing - would be good to try this on an FPGA or Verilog compiled for Pico and check interfacing with it works as expected.

Not doing because we've run out of space:
- Option to format debug for 7 segment (set option using another IO when reset\_en high)

Making the hardware usable:
- Modified version of the assembler supporting the new ops.
- Easy way to assemble a vasm program and build the output plus some data into a firmware for Pico
- Firmware for Pico to communicate with the PCB.  Ideally could be generally useful for any design.

# What is Tiny Tapeout?

TinyTapeout is an educational project that aims to make it easier and cheaper than ever to get your digital designs manufactured on a real chip!

Go to https://tinytapeout.com for instructions!

## How to change the Wokwi project

Edit the [info.yaml](info.yaml) and change the wokwi_id to match your project.

## How to enable the GitHub actions to build the ASIC files

Please see the instructions for:

* [Enabling GitHub Actions](https://tinytapeout.com/faq/#when-i-commit-my-change-the-gds-action-isnt-running)
* [Enabling GitHub Pages](https://tinytapeout.com/faq/#my-github-action-is-failing-on-the-pages-part)

## How does it work?

When you edit the info.yaml to choose a different ID, the [GitHub Action](.github/workflows/gds.yaml) will fetch the digital netlist of your design from Wokwi.

After that, the action uses the open source ASIC tool called [OpenLane](https://www.zerotoasiccourse.com/terminology/openlane/) to build the files needed to fabricate an ASIC.

## Resources

* [FAQ](https://tinytapeout.com/faq/)
* [Digital design lessons](https://tinytapeout.com/digital_design/)
* [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
* [Join the community](https://discord.gg/rPK2nSjxy8)

## What next?

* Share your GDS on Twitter, tag it [#tinytapeout](https://twitter.com/hashtag/tinytapeout?src=hashtag_click) and [link me](https://twitter.com/matthewvenn)!
