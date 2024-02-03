# asuscraper

Tool for import/export settings from an Asus router (using stock AsusWRT
firmware) using Selenium automation.  Not affiliated with Asus.

## Disclaimer

This product has only been tested on my personal routers from my personal
machine.  NO WARRANTY IS IMPLIED.  **This project is not affiliated with the
company named Asus A.K.A. "ASUSTeK COMPUTER INC." or any of their related
organizations.  DO NOT CONTACT THEM FOR SUPPORT**.

## Documentation

### What Is Powershell 

This is a Powershell module. If you're new to Powershell, Powershell is a
programming language that is automatically available on all modern Windows
computers, and can be installed onto most other computers. On Windows, you can
access the Powershell console by running "Powershell" in your start menu.

Powershell is a very useful language that is designed for easily manipulating
other programs on your Windows computer, as well as the Windows Operating System
itself.  It has good tools for shunting data from one system into another, as
you'll see in the CSV examples below.

Unfortunately, Powershell's development has been a bit turbulent and that has
produced a language that can be warty, inconsistent, and difficult to learn.
The usual joke is "two Googles per line".

But it's still useful, and you probably already have it.

### How To Install

In a Powershell console, execute the following:

```ps
Install-Module asuscraper
```

And work through the prompts.  If this is your first time installing a
Powershell module, you may need to change some settings to allow this to happen.
Details of that are out-of-scope of this document.

## Contribution

This project is brand new and so final contribution approach is still not fully
resolved.  Please reach out to me (Martin Zarate) if you're interested in
contributing.  This software was made to solve my own problems, so it is
unlikely I will be making any bugfixes beyond those that I need for it, but we
can discuss making your own contributions if you're interested.

### Coding Standards

This project attempts to follow PoshCode powershell standards, but with the amendment that backtick multiline continuations are acceptable.

https://github.com/PoshCode/PowerShellPracticeAndStyle