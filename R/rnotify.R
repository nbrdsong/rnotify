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
  stopifnot(is.numeric(offset_seconds), length(offset_seconds) == 1, is.finite(offset_seconds), offset_seconds >= 0)

  name <- gsub("[\r\n]+", " ", as.character(name))
  body <- if (is.null(body)) "" else as.character(body)
  list_name <- if (is.null(list_name)) "" else as.character(list_name)

  script <- c(
    'on run argv',
    '  -- tolerate accidental leading "--"',
    '  if (count of argv) ≥ 1 and item 1 of argv is "--" then',
    '    set argv to items 2 thru -1 of argv',
    '  end if',
    '  if (count of argv) < 4 then error "Expected 4 args (name, body, delay, list). Got " & (count of argv)',
    '  set theName to item 1 of argv',
    '  set theBody to item 2 of argv',
    '  set theDelay to (item 3 of argv) as number',
    '  set theListName to item 4 of argv',
    '  set remindTime to (current date) + theDelay',
    '  tell application "Reminders" to launch',
    '  with timeout of 15 seconds',
    '    tell application "Reminders"',
    '      if theListName is not "" then',
    '        try',
    '          set theList to first list whose name is theListName',
    '          make new reminder at end of reminders of theList with properties {name:theName, body:theBody, remind me date:remindTime}',
    '        on error',
    '          make new reminder with properties {name:theName, body:theBody, remind me date:remindTime}',
    '        end try',
    '      else',
    '        make new reminder with properties {name:theName, body:theBody, remind me date:remindTime}',
    '      end if',
    '    end tell',
    '  end timeout',
    'end run'
  )

  args <- c(as.vector(rbind("-e", script)),
            name, body, as.character(offset_seconds), list_name)

  out <- tryCatch(
    system2("/usr/bin/osascript", args = args, stdout = TRUE, stderr = TRUE),
    error = function(e) structure(character(), status = 1L, error = e)
  )

  status <- attr(out, "status")
  ok <- is.null(status) || identical(status, 0L)

  details <- ""
  if (!ok) {
    if (!is.null(attr(out, "error"))) details <- conditionMessage(attr(out, "error"))
    if (length(out)) details <- paste(c(details, out), collapse = "\n")
  } else if (isTRUE(debug) && length(out)) {
    details <- paste(out, collapse = "\n")
  }

  list(ok = ok, status = if (is.null(status)) 0L else status, details = details)
}
