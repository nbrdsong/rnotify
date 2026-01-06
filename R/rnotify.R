rnotify <- function(offset_seconds = 20,
                    list_name = NULL,     # set to a Reminders list name, or NULL for default
                    echo = TRUE,          # keeps your current behavior (prints code as it runs)
                    chdir = TRUE,
                    beep = TRUE,
                    beep_success = 3,
                    beep_error = 9,
                    debug_osascript = FALSE) {

  # macOS only
  if (Sys.info()[["sysname"]] != "Darwin") {
    message("Reminders notification only works on macOS.")
    return(invisible(NULL))
  }

  # Need RStudio API to find the active file
  if (!requireNamespace("rstudioapi", quietly = TRUE) || !rstudioapi::isAvailable()) {
    stop("rstudioapi is required and must be available (run inside RStudio).")
  }

  ctx <- tryCatch(rstudioapi::getActiveDocumentContext(), error = function(e) NULL)
  file <- if (!is.null(ctx)) ctx$path else ""

  if (!nzchar(file)) {
    .maybe_beep(beep, beep_error)
    message("Active file is unsaved or unavailable.")
    return(invisible(NULL))
  }
  file <- normalizePath(file, winslash = "/", mustWork = TRUE)

  err <- NULL
  tryCatch(
    source(file, echo = echo, chdir = chdir),
    error = function(e) err <<- e
  )

  ok <- is.null(err)
  .maybe_beep(beep, if (ok) beep_success else beep_error)

  base <- basename(file)
  msg  <- if (ok) paste(base, "finished OK.")
          else    paste(base, "errored:", conditionMessage(err))

  # Keep reminder title short-ish; put details in body
  stamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  name  <- paste0("[RStudio] ", msg)
  body  <- paste0(stamp, "\n", file, if (!ok) paste0("\n\n", conditionMessage(err)) else "")

  res <- reminders_add(name, body, offset_seconds = offset_seconds, list_name = list_name,
                       debug = debug_osascript)

  if (!res$ok) {
    message(
      "AppleScript/Reminders failed.\n",
      res$details,
      "\n\nIf this is a permissions issue: macOS System Settings → Privacy & Security → Automation → allow RStudio to control Reminders."
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

  name <- gsub("[\r\n]+", " ", name)
  body <- if (is.null(body)) "" else as.character(body)
  list_name <- if (is.null(list_name)) "" else as.character(list_name)

  script <- paste(c(
    'on run argv',
    'set theName to item 1 of argv',
    'set theBody to item 2 of argv',
    'set theDelay to (item 3 of argv) as number',
    'set theListName to item 4 of argv',
    'set remindTime to (current date) + theDelay',
    'tell application "Reminders" to launch',
    'with timeout of 15 seconds',
    '  tell application "Reminders"',
    '    if theListName is not "" then',
    '      try',
    '        set theList to list theListName',
    '        make new reminder at end of reminders of theList with properties {name:theName, body:theBody, remind me date:remindTime}',
    '      on error',
    '        make new reminder with properties {name:theName, body:theBody, remind me date:remindTime}',
    '      end try',
    '    else',
    '      make new reminder with properties {name:theName, body:theBody, remind me date:remindTime}',
    '    end if',
    '  end tell',
    'end timeout',
    'end run'
  ), collapse = "\n")

  args <- c(
    "-e", script, "--",
    name, body, as.character(offset_seconds), list_name
  )

  out <- tryCatch(
    system2("osascript", args = args, stdout = TRUE, stderr = TRUE, quote = TRUE),
    error = function(e) structure(character(), status = 1, error = e)
  )

  status <- attr(out, "status")
  ok <- is.null(status) || identical(status, 0L)
  details <- if (!ok || isTRUE(debug)) paste(out, collapse = "\n") else ""

  list(ok = ok, status = if (is.null(status)) 0L else status, details = details)
}

  script_args <- as.vector(rbind("-e", script))

  runtime_args <- c(name, body, as.character(offset_seconds), list_name)

  args <- c(script_args, "--", runtime_args)

  out <- tryCatch(
    system2("osascript", args = args,
          stdout = TRUE, stderr = TRUE),
    error = function(e) structure(character(), status = 1, error = e)
  )

  status <- attr(out, "status")
  ok <- is.null(status) || identical(status, 0L)

  details <- if (!ok) paste(out, collapse = "\n") else if (isTRUE(debug)) paste(out, collapse = "\n") else ""

  list(ok = ok, status = if (is.null(status)) 0L else status, details = details)
}
