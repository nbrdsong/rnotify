rnotify <- function() {
	
	# load required packages, install if not already
	req_pkgs <- c("rstudioapi", "beepr")
	new_pkgs <- req_pkgs[!(req_pkgs %in% rownames(installed.packages()))]
	if(length(new_pkgs)) {
		message("Installing missing packages: ", paste(new_pkgs, collapse = ", "))
		install.packages(new_pkgs, dependencies = TRUE)}
	lapply(req_pkgs, function(pkg) {
		suppressPackageStartupMessages(library(pkg, character.only = TRUE))})
	
	# get context of the currently active document
	ctx <- getActiveDocumentContext()
	file <- ctx$path
	
	# if file is untitled or not saved, this won't work
	if (is.null(file) || file == "") {
		beepr::beep(9)
		msg <- "Active file is unsaved or unavailable."
		message(msg)
		return(invisible(NULL))}
	
	# stream output to console while running
	source(file, echo = TRUE)
	
	if (inherits(result, "error")) {
		beepr::beep(9)
		msg <- paste(basename(file), "errored:", result$message)
	} else {
		beepr::beep(3)
		msg <- paste(basename(file), "finished OK.")}
	
	# send notification after 20 seconds through the reminders app
	offset_seconds <- 20
	msg <- "Notification from R! Script is done running."
	
	applescript <- sprintf(
		'osascript -e \'tell application "Reminders"
      set remindTime to (current date) + %d
      make new reminder with properties {name:"%s", remind me date:remindTime}
  end tell\'',
		offset_seconds, msg)
	try(system(applescript, ignore.stdout = TRUE, ignore.stderr = TRUE), silent = TRUE)
	
	message(msg)
}

