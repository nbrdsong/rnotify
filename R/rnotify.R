rnotify <- function(offset_seconds = 20,
                    list_name = NULL,     # optional: a Reminders list name (e.g., "Reminders"); NULL uses default
                    echo = TRUE,          # preserves your current behavior (prints code as it runs)
                    chdir = TRUE,         # run as if the script's folder is the working directory
                    beep = TRUE,          # optional sound; silently skipped if beepr isn't installed
                    beep_success = 3,
                    beep_error = 9,
                    debug_osascript = FALSE) {

  stopifnot(is.numeric(offset_seconds), length(offset_seconds) == 1,
            is.finite(offset_seconds), offset_seconds >= 0)

  # Check for macOS
  if (Sys.info()[["sysname"]] != "Darwin") {
    message("Reminders notification only works on macOS.")
    return(invisible(NULL))
  }

  # Need RStudio API to find the active file
  if (!requireNamespace("rstudioapi", quietly = TRUE) || !rstudioapi::isAvailable()) {
    stop("rstudioapi is required and must be available (run inside RStudio).")
  }

  # Get active RStudio file
  ctx <- tryCatch(rstudioapi::getActiveDocumentContext(), error = function(e) NULL)
  file <- if (!is.null(ctx)) ctx$path else ""

  if (!nzchar(file)) {
    .maybe_beep(beep, beep_error)
    message("Active file is unsaved or unavailable.")
    return(invisible(NULL))
  }

  file <- normalizePath(file, winslash = "/", mustWork = TRUE)

  # Run script; DO NOT store source() return value (avoids accidental large duplication)
  err <- NULL
  tryCatch(
    source(file, echo = echo, chdir = chdir),
    error = function(e) err <<- e,
    interrupt = function(e) err <<- e
  )

  ok <- is.null(err)
  .maybe_beep(beep, if (ok) beep_success else beep_error)

  base <- basename(file)
  msg  <- if (ok) paste(base, "finished OK.")
          else    paste(base, "stopped:", conditionMessage(err))

  stamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  name  <- paste0("[RStudio] ", msg)
  body  <- paste0(stamp, "\n", file, if (!ok) paste0("\n\n", conditionMessage(err)) else "")

  res <- reminders_add(name = name, body = body,
                       offset_seconds = offset_seconds,
                       list_name = list_name,
                       debug = debug_osascript)

  if (!res$ok) {
    message(
      "AppleScript/Reminders failed.\n",
      if (nzchar(res$details)) paste0(res$details, "\n") else "",
      "\nIf this is a permissions issue: macOS System Settings → Privacy & Security → Automation → allow RStudio to control Reminders."
    )
  } else {
    message("Scheduled reminder: ", msg)
  }

  invisible(list(ok = ok, file = file, error = err, reminders = res))
}

.maybe_beep <- function(enabled, sound) {
  if (!isTRUE(enabled)) return(invisible(NULL))
  if (!requireNamespace("beepr", quietly = TRUE)) return(invisible(NULL))
  try(beepr::beep(sound), silent = TRUE)
  invisible(NULL)
}

reminders_add <- function(name, body = "", offset_seconds = 20, list_name = NULL, debug = FALSE) {
  stopifnot(is.numeric(offset_seconds), length(offset_seconds) == 1,
            is.finite(offset_seconds), offset_seconds >= 0)

  # Sanitize inputs
  name <- gsub("[\r\n]+", " ", as.character(name))
  name <- gsub('"', '\\\\"', name)  # escape quotes
  body <- gsub('"', '\\\\"', as.character(body))  # escape quotes
  
  # Build AppleScript with proper list handling
  if (!is.null(list_name) && nzchar(list_name)) {
    list_name <- gsub('"', '\\\\"', as.character(list_name))
    script <- sprintf(
      'tell application "Reminders"
        set remindTime to (current date) + %d
        try
          set theList to (first list whose name is "%s")
          make new reminder at end of reminders of theList with properties {name:"%s", body:"%s", remind me date:remindTime}
        on error
          make new reminder with properties {name:"%s", body:"%s", remind me date:remindTime}
        end try
      end tell',
      offset_seconds, list_name, name, body, name, body
    )
  } else {
    script <- sprintf(
      'tell application "Reminders"
        set remindTime to (current date) + %d
        make new reminder with properties {name:"%s", body:"%s", remind me date:remindTime}
      end tell',
      offset_seconds, name, body
    )
  }
  
  cmd <- sprintf("osascript -e '%s'", script)
  
  if (debug) {
    message("Command being executed:")
    message(cmd)
  }
  
  out <- tryCatch(
    system(cmd, intern = TRUE, ignore.stderr = FALSE),
    error = function(e) structure(character(), error = e),
    warning = function(w) structure(character(), warning = w)
  )
  
  ok <- is.null(attr(out, "error")) && is.null(attr(out, "warning"))
  details <- if (!ok || isTRUE(debug)) paste(out, collapse = "\n") else ""
  
  list(ok = ok, status = if (ok) 0L else 1L, details = details)
}
