# rnotify

Running some code in RStudio that might take a while to run? Can't do much else until it is done? Don't want to walk away from your computer in case it breaks/finishes, but also have other things you could be doing like going for a walk, eating lunch, or staring at other screens? Have you also bought into the Apple ecosystem? If yes to all of these questions, you might find this kind of neat.

This is an RStudio addin that sends notifications via Apple's Reminders app (and plays a noise via your computer's speakers) once a script file finishes running. This allows you to get notified on your iPhone and/or Apple Watch if your script completes or errors out. 

# Features

- One-click RStudio Addin: no manual sourcing required.
- Plays a beep on finish or error.
- Sends a Reminders notification on macOS.
- Live, interactive output—see script progress in your Console.
- Easy installation: install the package, and you’re ready to go.

# Requirements

- R version >= 3.5.0
- RStudio (Addin menu requires RStudio)
- macOS (Reminders notification uses macOS native scripting)
- R packages: rstudioapi, beepr (Will be installed automatically if you use the package, but you can pre-install)

# Installation

You can install rnotify directly from GitHub using the devtools or remotes package:

- Install devtools if you don't have it: install.packages("devtools")
- devtools::install_github("nbrdsong/rnotify")

Alternatively, you may download the ZIP file from the GitHub repository and install manually in R:

- Use the path to the downloaded folder: install.packages("/path/to/rnotify", repos = NULL, type = "source")

Restart RStudio after install.

You also need to enable notifications on your phone or other Apple devices if you want to actually get notified on those devices.

# Usage

Once installed, the addin will appear in the RStudio Addins menu.

To use:

- Open the R script you want to run in RStudio.
- Make sure the script file is saved.
- Go to Tools → Addins → Run Script with Notification (under RNOTIFY).
- The script runs in your Console. When finished, you will hear a beep and a Reminders notification will be scheduled for you in your default list in the Reminders app.

Console output:

You’ll see all output printed to the Console live, just as if you had manually sourced your script (more or less).

Error handling:

If an error occurs, you’ll hear a different beep and see an error message in your console.

# Manual Source Mode

If you do not want to install the package, you can use the function directly:

- Download rnotify.R from this repository.
- Place it in your working directory.
- Run in your R console:

source("rnotify.R")
rnotify()

Note: The addin menu and Reminders integration only work in RStudio on a Mac.

# Troubleshooting

## No addin in RStudio menu?
Make sure you have the latest RStudio.
Try restarting RStudio after install.
Check that inst/rstudio/addins.dcf exists in the package—reinstall if missing.

## Reminders notification doesn’t work?
This feature is for macOS only.
Confirm you've given R access to control Reminders in System Preferences → Security & Privacy → Automation.

## Beep doesn’t play?
Ensure the beepr package is installed and your sound is enabled.

## Console looks weird?

I am not sure how to fix that, at least without more effort than it would be worth. It happens because of how this addin works: it runs your .R file after wrapping the entire thing in code that sends the notification. Otherwise, it wouldn't be able to send a notification when code breaks. To get anything to show up in the console, it has to print an echo of it.

# Customization

You can edit the notification delay (offset_seconds) in rnotify.R.
Replace the Reminders code section for different OS notifications if desired.

# Contributing

Pull requests and suggestions are welcome! Please open Issues for bugs or ideas.

# License

MIT License
