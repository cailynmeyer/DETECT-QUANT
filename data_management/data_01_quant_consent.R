# Pull and clean DETECT Dyad Quantitative consent data from REDCap.
#
# Pulls ONLY the fields the consent dashboard needs, with raw codes, and writes
# one cleaned row per REDCap record to data/quant/quant_consent_cleaned.RDS.
#
#   Rscript data_management/data_01_quant_consent.R
#
# Run from the repository root. Needs the `detect_quant_redcap_api` token in
# .Renviron or the system keyring (see README -> API Keys).
#
# Identifiers on the consent form (names, email, signature, phone number, date
# of birth) are deliberately NOT requested. Add a field to `fields_to_pull` only
# if a dashboard view needs it -- the rendered site is published.

library(dplyr, warn.conflicts = FALSE)
library(fs)
library(REDCapR)

source(here::here("r", "get_api_token.R"))
source(here::here("r", "codebook.R"))
source(here::here("r", "clean_quant_consent.R"))

#### Fields -------------------------------------------------------------------

# Checkbox fields are listed by their base name; REDCap expands them into
# <field>___<code> columns (e.g. sode_adrd___1).
consent_fields <- c(
    "admin_record_id",
    "admin_dyad",
    "admin_start_dt",
    "admin_institution",
    "admin_institution_2",
    "co_authorization",
    "co_sign_dt",
    "admin_qual",
    "admin_qual_time",
    "admin_role",
    "co_sign_rep",
    "co_rep_relationship",
    "sode_adrd"
)

# Each item has a self-report version and a _proxy version (caregiver answering
# about the care recipient). Age is kept; date of birth is not pulled.
sociodemographic_fields <- c(
    "sode_hispanic", "sode_hispanic_proxy",
    "sode_race", "sode_race_proxy",
    "sode_age", "sode_age_proxy",
    "sogi_sex", "sogi_sex_proxy",
    "sode_marital", "sode_marital_proxy",
    "sode_military", "sode_military_proxy",
    "sode_people", "sode_people_proxy",
    "sode_school", "sode_school_proxy",
    "sode_income", "sode_income_proxy"
)

form_status_fields <- paste0(names(instrument_labels), "_complete")

fields_to_pull <- c(consent_fields, sociodemographic_fields, form_status_fields)

#### Pull ---------------------------------------------------------------------

get_data <- function(token = get_api_token("detect_quant_redcap_api")) {
    redcap_read(
        redcap_uri = "https://redcap.uth.tmc.edu/api/",
        token = token,
        fields = fields_to_pull,
        raw_or_label = "raw",
        # Adds each survey's completion timestamp (e.g. consent_timestamp), used
        # to tell a submitted consent from one that was started and abandoned.
        export_survey_fields = TRUE,
        continue_on_error = FALSE
    )
}

pulled <- get_data()
raw <- pulled$data

# If the project ever uses repeating instruments, keep only the base
# (non-repeating) row for each record so counts stay one-per-participant.
if ("redcap_repeat_instrument" %in% names(raw)) {
    raw <- raw |> filter(is.na(redcap_repeat_instrument))
}

#### Clean --------------------------------------------------------------------

cleaned <- clean_quant_consent(raw)

#### Save ---------------------------------------------------------------------

DIRECTORY <- here::here("data", "quant")
if (!dir_exists(DIRECTORY)) dir_create(DIRECTORY)

saveRDS(cleaned, path(DIRECTORY, "quant_consent_cleaned.RDS"))
message(glue::glue("Wrote {nrow(cleaned)} records to {DIRECTORY}/quant_consent_cleaned.RDS"))
