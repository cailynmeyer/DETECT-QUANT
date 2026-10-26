#' Retrieve an API token from the environment or the system keyring
#'
#' Looks for the token in an environment variable first (e.g. one set in
#' `.Renviron`), and falls back to the system keyring set with
#' `keyring::key_set()`. This lets the dashboards read tokens whether they are
#' stored in `.Renviron` or the OS keychain, so a missing keychain entry no
#' longer breaks the data-prep scripts.
#'
#' @param name Service / environment-variable name, e.g.
#'   "detect_tool_redcap_api". The same string is used to look up both the
#'   environment variable and the keyring service.
#' @return The token string. Errors with setup instructions if not found in
#'   either location.
get_api_token <- function(name) {
    # 1. Environment variable (e.g. from .Renviron)
    token <- Sys.getenv(name, unset = NA_character_)
    if (!is.na(token) && nzchar(token)) {
        return(token)
    }

    # 2. Fall back to the system keyring
    token <- tryCatch(
        keyring::key_get(name),
        error = function(e) NA_character_
    )
    if (!is.na(token) && nzchar(token)) {
        return(token)
    }

    stop(
        sprintf(
            paste0(
                "API token '%s' not found.\n",
                "Set it in ONE of these two places:\n",
                "  * .Renviron (in the project root):  %s=your_token_here\n",
                "  * the system keyring:               keyring::key_set(\"%s\")"
            ),
            name,
            name,
            name
        ),
        call. = FALSE
    )
}
