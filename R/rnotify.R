rnotify <- function(offset_seconds = 20) {
	
	# Check for macOS
	if (Sys.info()["sysname"] != "Darwin") {
		message("Reminders notification only works on macOS.")
		return(invisible(NULL))
	}
	
	# Handle packages
	req_pkgs <- c("rstudioapi", "beepr")
	new_pkgs <- req_pkgs[!(req_pkgs %in% rownames(installed.packages()))]
	if(length(new_pkgs)) {
		message("Installing missing packages: ", paste(new_pkgs, collapse = ", "))
		install.packages(new_pkgs, dependencies = TRUE)
	}
	lapply(req_pkgs, function(pkg) {
		suppressPackageStartupMessages(library(pkg, character.only = TRUE))
	})
	
	# Get active RStudio file
	ctx <- rstudioapi::getActiveDocumentContext()
	file <- ctx$path
	
	if(is.null(file) || file == "") {
		beepr::beep(9)
		msg <- "Active file is unsaved or unavailable."
		message(msg)
		return(invisible(NULL))
	}
	
	# Run script and capture result
	result <- tryCatch(
		source(file, echo = TRUE), 
		error = function(e) e
	)
	
	if (inherits(result, "error")) {
		beepr::beep(9)
		msg <- paste(basename(file), "errored:", result$message)
	} else {
		beepr::beep(3)
		msg <- paste(basename(file), "finished OK.")
	}
	
	# Set unique reminder text and timestamp
	applescript <- sprintf(
		'osascript -e \'tell application "Reminders"
      set remindTime to (current date) + %d
      make new reminder with properties {name:"%s", remind me date:remindTime}
    end tell\'',
		offset_seconds, gsub('"', '\\"', msg) # escape quotes
	)
	
	# For development, capture output/errors
	sys_result <- try(system(applescript, intern = TRUE, ignore.stderr = FALSE), silent = TRUE)
	if(inherits(sys_result, "try-error")) {
		message("AppleScript notification failed:", sys_result)
	} else {
		message("Scheduled notification:", msg)
	}
	
	invisible(NULL)
}