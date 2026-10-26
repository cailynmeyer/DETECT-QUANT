# Build FAKE consent data for previewing the dashboard without REDCap access.
#
# Generates random records shaped like the raw REDCap pull (same field names
# and raw codes as the codebook), runs them through the real cleaning function,
# and writes data_management/mock_data/quant_consent_mock.RDS. Nothing here is
# real participant data.
#
#   Rscript data_management/mock_data/make_mock_data.R
#   DETECT_QUANT_MOCK=1 quarto render     # dashboard reads the mock file

library(dplyr, warn.conflicts = FALSE)

source(here::here("r", "codebook.R"))
source(here::here("r", "clean_quant_consent.R"))

set.seed(2026)
n <- 180

draw <- function(codes, prob = NULL) sample(codes, n, replace = TRUE, prob = prob)
with_missing <- function(x, rate) replace(x, runif(n) < rate, NA)

start_dt <- as.POSIXct("2026-01-12 09:00", tz = "UTC") + runif(n, 0, 280 * 86400)

raw <- tibble(
    admin_record_id = seq_len(n),
    admin_dyad = paste0("D", sprintf("%03d", sample(1:95, n, replace = TRUE))),
    admin_start_dt = format(start_dt, "%Y-%m-%d %H:%M"),
    # Site normally arrives via the survey link; a few forms keep the default 0.
    # admin_institution_2 never shows (its branching needs a blank, not 0).
    admin_institution = draw(0:7, c(0.03, rep(0.97 / 7, 7))),
    admin_institution_2 = NA_integer_,
    co_authorization = with_missing(draw(c(1, 0), c(0.85, 0.15)), 0.05)
) |>
    mutate(
        signed = co_authorization %in% 1,
        # Most consent surveys are submitted; a few are abandoned part-way
        consent_timestamp = if_else(
            !is.na(co_authorization) & runif(n) > 0.05,
            format(start_dt + 900, "%Y-%m-%d %H:%M:%S"),
            "[not completed]"
        ),
        co_sign_dt = if_else(signed, format(start_dt + 600, "%Y-%m-%d %H:%M"), NA_character_),
        admin_qual = if_else(signed, draw(c(1, 0), c(0.6, 0.4)), NA_real_),
        admin_role = if_else(signed, draw(c(1, 2), c(0.45, 0.55)), NA_real_),
        co_sign_rep = if_else(admin_role %in% 2, draw(c(0, 1), c(0.6, 0.4)), NA_real_),
        co_rep_relationship = if_else(co_sign_rep %in% 1, draw(1:14, c(5, 1, 1, 6, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1)), NA_integer_),
        proxy = co_sign_rep %in% 1,
        self = signed & !proxy,
        sode_hispanic = if_else(self, draw(c(1, 2, 777, 999), c(3, 6, 0.5, 0.5)), NA_real_),
        sode_hispanic_proxy = if_else(proxy, draw(c(1, 2, 777, 999), c(3, 6, 0.5, 0.5)), NA_real_),
        sode_age = if_else(self, round(runif(n, 30, 95)), NA_real_),
        sode_age_proxy = if_else(proxy, round(runif(n, 60, 100)), NA_real_),
        sogi_sex = if_else(self, draw(c(1, 2, 999), c(4, 6, 0.3)), NA_real_),
        sogi_sex_proxy = if_else(proxy, draw(c(1, 2, 999), c(4, 6, 0.3)), NA_real_),
        sode_marital = if_else(self, draw(c(1:6, 777, 999), c(4, 1, 1, 2, 3, 2, 0.2, 0.3)), NA_real_),
        sode_marital_proxy = if_else(proxy, draw(c(1:6, 777, 999), c(4, 1, 1, 2, 3, 2, 0.2, 0.3)), NA_real_),
        sode_military = if_else(self, draw(c(1, 2, 999), c(2, 8, 0.3)), NA_real_),
        sode_military_proxy = if_else(proxy, draw(c(1, 2, 999), c(2, 8, 0.3)), NA_real_),
        sode_people = if_else(self, draw(1:6), NA_integer_),
        sode_people_proxy = if_else(proxy, draw(1:6), NA_integer_),
        sode_school = if_else(self, draw(c(1:7, 999), c(2, 4, 3, 2, 2, 1, 1, 0.3)), NA_real_),
        sode_school_proxy = if_else(proxy, draw(c(1:7, 999), c(2, 4, 3, 2, 2, 1, 1, 0.3)), NA_real_),
        sode_income = if_else(self, draw(c(1:7, 777, 999), c(2, 3, 3, 2, 2, 1, 1, 1, 1.5)), NA_real_),
        sode_income_proxy = if_else(proxy, draw(c(1:7, 777, 999), c(2, 3, 3, 2, 2, 1, 1, 1, 1.5)), NA_real_)
    )

# Checkboxes: one 0/1 column per code
for (code in names(qual_time_labels)) {
    raw[[paste0("admin_qual_time___", code)]] <- as.integer(raw$admin_qual %in% 1 & runif(n) < 0.3)
}
for (code in names(adrd_labels)) {
    raw[[paste0("sode_adrd___", code)]] <- as.integer(raw$admin_role %in% 2 & runif(n) < c("1" = 0.35, "2" = 0.2, "3" = 0.15, "4" = 0.3, "777" = 0.05, "999" = 0.02)[[code]])
}
for (code in names(race_labels)) {
    p <- c("1" = 0.5, "2" = 0.3, "3" = 0.08, "4" = 0.03, "5" = 0.02, "6" = 0.02, "7" = 0.04, "777" = 0.02, "999" = 0.02)[[code]]
    raw[[paste0("sode_race___", code)]] <- as.integer(raw$self & runif(n) < p)
    raw[[paste0("sode_race_proxy___", code)]] <- as.integer(raw$proxy & runif(n) < p)
}

# Form status: forms fill in order and drop off as the survey goes on
forms <- names(instrument_labels)
reached <- ifelse(raw$signed, sample(1:length(forms), n, replace = TRUE, prob = c(1, 1, 1, 1, 1, 2, 3, 10)), 1)
for (i in seq_along(forms)) {
    status <- case_when(
        i < reached ~ 2,
        i == reached ~ sample(c(0, 1, 2), n, replace = TRUE, prob = c(2, 1, 7)),
        TRUE ~ NA_real_
    )
    # Caregiver Questions only applies to caregivers
    if (forms[i] == "caregiver_questions") status[!raw$admin_role %in% 2] <- NA
    raw[[paste0(forms[i], "_complete")]] <- status
}

# An abandoned consent survey leaves the Consent form Incomplete
raw$consent_complete[raw$consent_timestamp == "[not completed]"] <- 0

mock <- clean_quant_consent(raw)

out <- here::here("data_management", "mock_data", "quant_consent_mock.RDS")
saveRDS(mock, out)
message("Wrote ", nrow(mock), " FAKE records to ", out)
